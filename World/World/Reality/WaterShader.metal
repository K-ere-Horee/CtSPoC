//
//  WaterShader.metal
//  World
//
//  Real-time water shader for `water_surface.usdz`, per the asset repo's explicit follow-up
//  task (FishAssets/Environment/Documentation/Source_Log.md, Asset 2: "animated normals, two
//  layers, differing scale+direction; ripple displacement — the 1.33m grid exists to carry it;
//  refraction + depth fade; specular tuned to the golden-hour sun").
//
//  Ripple **detail** now comes from a real, sourced normal-map texture (`water_normal.jpg`, see
//  `WaterMaterial.swift` for provenance/license), not purely-analytic sine waves — after repeated
//  procedural attempts (regular sine-wave normals, then a fake reflection pattern keyed to the
//  camera's own position) kept reading as visibly synthetic, the user asked directly: "can we use
//  free water texture instead?" Three independently-scrolling/tiled samples of the same normal map
//  (originally two — a third was added in a later pass to break up residual visible repetition
//  without raising overall bumpiness, see `waterSurfaceShader`) are combined for ripple detail, the
//  classic technique (used, among many other places, in three.js's own reference water shader — the
//  same repo this texture is sourced from). Large-scale
//  swell **displacement** (actual vertex movement, not just shading) is still analytic — a
//  procedural low-frequency sine sum is the right tool for slow, big, smooth undulation, and no
//  texture is needed for that part.
//
//  True screen-space refraction of the underwater terrain and a real depth-buffer compare for
//  depth fade are not exposed at this material-system level (per the surface-shader API below —
//  there is no "sample what's behind this fragment" primitive). Depth fade is approximated with
//  a world-position-based color gradient using the lake's own authored depth profile (shallow
//  ~0.6m shelf near the dock at worldPos.z ~ 0..10, grading to the ~11m open basin by
//  worldPos.z ~ -30) — a stand-in, not the real thing, exactly as flagged as acceptable.
//
//  A true planar mirror reflection (rendering the scene from a camera mirrored across the water
//  plane into a texture, sampled here) would show actual tree/terrain shapes — not attempted, a
//  meaningfully bigger engineering task (second offscreen camera pass, no existing infrastructure
//  for it in this codebase) than anything in this file. What's here instead reflects the real sky
//  texture (sampled by the true reflection vector's angle) plus a subtle shoreline-color hint.
//

#include <RealityKit/RealityKit.h>
#include <metal_stdlib>

using namespace metal;

namespace {

/// One sine wave term: direction (in the water plane), wavelength, amplitude, and phase speed.
struct WaveTerm {
    float2 direction;
    float wavelength;
    float amplitude;
    float speed;
};

inline void accumulateWave(WaveTerm term, float2 p, float t, thread float &height, thread float2 &slope)
{
    float2 dir = normalize(term.direction);
    float k = 2.0 * M_PI_F / term.wavelength;
    float phase = dot(dir, p) * k - t * term.speed;
    height += term.amplitude * sin(phase);
    float dHeightDPhase = term.amplitude * k * cos(phase);
    slope += dir * dHeightDPhase;
}

/// Two coarse "swell" waves only — real vertex displacement, slow/large-scale undulation. Fine
/// ripple detail is no longer analytic (see file header) — it comes from `water_normal.jpg`
/// instead, sampled in the surface shader.
inline float waterHeightField(float2 p, float t, thread float2 &slope)
{
    float height = 0.0;
    slope = float2(0.0);
    // Amplitudes halved from the first pass (0.06/0.035 -> 0.03/0.018): user feedback ("the
    // animation waves... still look odd and unnatural") against a Blender reference render showing
    // a much calmer surface — a stocked pond shouldn't have visibly rolling swell, only gentle,
    // slow undulation.
    accumulateWave(WaveTerm{ float2(0.8, 0.6), 6.0, 0.03, 0.62 }, p, t, height, slope);
    accumulateWave(WaveTerm{ float2(-0.5, 0.85), 3.7, 0.018, 0.68 }, p, t, height, slope);
    return height;
}

}

/// Geometry modifier: displaces every vertex vertically by the analytic swell height, and sets a
/// coarse base normal from the same function's closed-form slope. This is deliberately just the
/// big, slow undulation — fine ripple detail is layered on top in the surface shader from the real
/// normal-map texture, not computed here.
[[visible]]
void waterGeometryModifier(realitykit::geometry_parameters params)
{
    auto geo = params.geometry();
    float t = params.uniforms().time();

    float3 modelPos = geo.model_position();
    float2 slope;
    float height = waterHeightField(modelPos.xz, t, slope);

    geo.set_model_position_offset(float3(0.0, height, 0.0));

    // Standard height-field normal: for y = h(x, z), N = normalize(-dh/dx, 1, -dh/dz).
    float3 normal = normalize(float3(-slope.x, 1.0, -slope.y));
    geo.set_normal(normal);
}

/// Surface shader: samples the real water-normal texture twice (independently scrolling/tiled) for
/// fine ripple detail, blends a depth-based base color with a real sky reflection (sampled from the
/// same equirect texture the sky dome displays, by the *actual* reflection vector) via a Fresnel
/// term, and adds a small direct sparkle highlight.
[[visible]]
void waterSurfaceShader(realitykit::surface_parameters params)
{
    auto surf = params.surface();
    auto geo = params.geometry();
    auto tex = params.textures();
    float t = params.uniforms().time();

    float3 modelPos = geo.model_position();

    // --- Fine ripple normal detail from the real texture ---
    // THREE samples now (was two), different tiling scale/direction/speed each (the classic
    // technique — same one used in three.js's own reference water shader, the source of this
    // texture), extended by one more independent layer. The user's complaint after the earlier
    // "calm it down" pass was that the water *still* looks odd/unnatural — not that it needed more
    // amplitude (that was already tried and reverted once this session), but that a two-tile
    // pattern still shows a faint repeating rhythm once you watch it move. A third sample at a
    // scale/direction/speed unrelated to the other two breaks that residual regularity without
    // raising the overall bumpiness (see the reduced per-sample strength below). UV0 spans the
    // full 80x60 m water sheet 0..1 (per the asset repo's own docs).
    constexpr sampler waterSampler(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
    float2 uv0 = geo.uv0();
    // Tiling ~30 / ~21 (unchanged scale from before, slightly faster scroll for more visible life
    // at a static glance) plus a new, much finer ~46 tile third layer moving in yet another
    // direction — the fine layer is what actually reads as "detail" up close, while A/B carry the
    // broader ripple shape.
    float2 uvA = uv0 * 30.0 + float2(t * 0.024, t * 0.015);
    float2 uvB = uv0 * 21.0 + float2(-t * 0.013, t * 0.021) + float2(0.37, 0.61);
    float2 uvC = uv0 * 46.0 + float2(t * 0.031, -t * 0.019) + float2(0.81, 0.14);
    half3 tsNormalA = realitykit::unpack_normal(tex.normal().sample(waterSampler, uvA).rgb);
    half3 tsNormalB = realitykit::unpack_normal(tex.normal().sample(waterSampler, uvB).rgb);
    half3 tsNormalC = realitykit::unpack_normal(tex.normal().sample(waterSampler, uvC).rgb);
    // Per-sample strength reduced from the old two-sample 0.45 down to 0.34 each — adding a third
    // layer at the *same* per-sample strength would net-increase total bumpiness right back toward
    // the "busy/noisy" look an earlier pass deliberately calmed down; dropping each layer's
    // contribution keeps the combined magnitude roughly where it was while trading "more amplitude"
    // for "more varied pattern" (three independent frequencies/directions instead of two, so no
    // single tile's repeat is as easy to spot). "Whiteout" blend (sum xy, multiply z) extended to
    // three normals the same way it combined two.
    half normalStrength = half(0.34);
    half3 tsNormalASoft = normalize(half3(tsNormalA.xy * normalStrength, tsNormalA.z));
    half3 tsNormalBSoft = normalize(half3(tsNormalB.xy * normalStrength, tsNormalB.z));
    half3 tsNormalCSoft = normalize(half3(tsNormalC.xy * normalStrength, tsNormalC.z));
    half3 tsNormal = normalize(half3(
        tsNormalASoft.xy + tsNormalBSoft.xy + tsNormalCSoft.xy,
        tsNormalASoft.z * tsNormalBSoft.z * tsNormalCSoft.z
    ));
    surf.set_normal(float3(tsNormal));

    // Reconstruct the same perturbed normal in world space myself (not just handed to RealityKit's
    // own lighting via surf.set_normal above) so the Fresnel/reflection/sparkle logic
    // below responds to the *actual* rippled surface, not just the coarse geometry-modifier normal.
    float3 T = normalize(geo.tangent());
    float3 B = normalize(geo.bitangent());
    float3 N = normalize(geo.normal());
    float3 normal = normalize(T * float(tsNormal.x) + B * float(tsNormal.y) + N * float(tsNormal.z));

    // --- Depth-based base color (approximate depth fade, see file header) ---
    // worldPos.z: verified convention (see WorldViewModel/EnvironmentSceneBuilder comments) —
    // positive z is toward the dock/shore, negative z is out over the open basin. Shelf under
    // the dock is ~0..10, open basin extends out past -20/-30. Murky olive-green "pond" palette,
    // not clear blue lake water (user feedback: a pale blue-gray tone read as a pool, not a
    // stocked pond with algae/sediment). Darkens over 25 m, not 40 — a pond doesn't stay
    // "shallow-clear" that far out.
    half3 shallowColor = half3(0.22, 0.34, 0.22);
    half3 deepColor = half3(0.02, 0.06, 0.05);
    float depthT = clamp((10.0 - modelPos.z) / 25.0, 0.0, 1.0);
    half3 depthColor = mix(shallowColor, deepColor, half(depthT));

    // --- Fresnel (Schlick's approximation) ---
    // Near-zero reflectance looking straight down, rising toward grazing angles. Capped well below
    // 1.0 (0.55) — even a much higher cap left the water reading as mostly pale reflected-sky tone
    // across this near-horizontal camera view over an 80 m lake; a pond's algae/sediment also
    // genuinely scatters more and mirrors less than clear water, which a lower cap approximates.
    float3 viewDir = normalize(geo.view_direction());
    float nDotV = saturate(dot(normal, viewDir));
    float fresnel = mix(0.03, 0.55, pow(1.0 - nDotV, 5.0));

    // --- Real sky reflection ---
    // Sampled from the actual equirectangular sky texture (bound into this material's otherwise-
    // unused `baseColor` texture slot — see WaterMaterial.swift) by the *real* reflection vector's
    // spherical angle, not a synthetic pattern. Converts world-space reflectDir (RealityKit Y-up)
    // to the Blender Z-up space the sky texture/dome mesh were authored in, then to the same
    // equirect UV formula the dome generator itself used (u = longitude/2π, v = 0.5 + latitude/π —
    // see the asset repo's `gen_dome.py`). A small rotational offset against the literal visible
    // dome is expected/acceptable; what matters is sampling real sky content by a real angle.
    float3 reflectDir = reflect(-viewDir, normal);
    float lonRad = atan2(-reflectDir.z, reflectDir.x);
    float latRad = asin(clamp(reflectDir.y, -1.0, 1.0));
    float2 skyUV = float2(lonRad / (2.0 * M_PI_F) + 0.5, 0.5 + latRad / M_PI_F);
    constexpr sampler skySampler(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
    half3 skyReflection = tex.base_color().sample(skySampler, skyUV).rgb;

    // Small, subtle hint of the shoreline's own color just above the mirror-horizon (a real
    // reflection would show the treeline there, not open sky) — half-strength so it reads as a
    // soft tint at the horizon line, not an independently-noticeable pattern.
    float terrainBand = saturate(smoothstep(-0.03, 0.03, reflectDir.y) * (1.0 - smoothstep(0.03, 0.12, reflectDir.y)));
    half3 shoreColor = half3(0.20, 0.26, 0.15);
    half3 reflectedColor = mix(skyReflection, shoreColor, half(terrainBand) * half(0.5));

    half3 color = mix(depthColor, reflectedColor, half(fresnel));

    surf.set_base_color(color);
    // Softened from the previous pass (0.14 -> 0.10 roughness) now that the normal-map strength
    // itself is toned down — a calmer surface reads best with a smoother, slightly more mirror-like
    // response, closer to the soft even sheen in the Blender reference render, rather than the
    // rougher/busier look that combination produced before.
    surf.set_roughness(half(0.10));
    surf.set_specular(half(0.7));
    surf.set_metallic(half(0.0));

    // --- Direct sparkle/glint ---
    // Added via emissive rather than relying on RealityKit's automatic lit-material specular
    // response (tested earlier in this shader's history with the old analytic normal — produced
    // zero visible sparkle). Uses a fixed, mostly-overhead virtual light (biased toward the viewer)
    // rather than the true sun — the sun sits deliberately behind-left of the player (AGENTS §4.6),
    // so its true specular reflection off water lands behind the camera, never in the forward view
    // actually being rendered. Toned down from the first pass (2.5 -> 1.1 intensity) — combined with
    // the busier normal map it read as blotchy/unnatural rather than a subtle shimmer.
    float3 glintDir = normalize(float3(0.0, 1.0, 0.0) + viewDir * 0.5);
    float specAngle = saturate(dot(normal, glintDir));
    float glint = pow(specAngle, 14.0) * 1.1;
    half3 sunGlintColor = half3(1.0, 0.95, 0.82);
    surf.set_emissive_color(half3(glint) * sunGlintColor);
}
