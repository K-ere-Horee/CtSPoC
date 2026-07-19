//
//  WaterMaterial.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 17/07/26.
//

import RealityKit
import Metal

/// Builds the real-time water material (see `WaterShader.metal` for the actual shader code and
/// the full rationale for what's genuinely animated vs. approximated) and applies it to the
/// loaded `water_surface` entity's model.
@MainActor
enum WaterMaterial {

    /// Finds the first `ModelEntity` in `entity`'s hierarchy and replaces its materials with the
    /// custom water material. Fails silently (leaving the shipped placeholder material in place)
    /// if the Metal library/shader functions can't be loaded — this should only happen if the
    /// `.metal` file failed to compile into the app's default library, and we'd rather ship the
    /// static placeholder than crash.
    static func apply(to entity: Entity) {
        guard let modelEntity = findModelEntity(in: entity) else { return }
        guard let material = try? makeMaterial() else { return }

        let materialCount = modelEntity.model?.materials.count ?? 1
        modelEntity.model?.materials = Array(repeating: material, count: max(1, materialCount))
    }

    private static func makeMaterial() throws -> CustomMaterial {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MaterialError.noMetalDevice
        }
        guard let library = device.makeDefaultLibrary() else {
            throw MaterialError.noDefaultLibrary
        }

        let surfaceShader = CustomMaterial.SurfaceShader(named: "waterSurfaceShader", in: library)
        let geometryModifier = CustomMaterial.GeometryModifier(named: "waterGeometryModifier", in: library)

        var material = try CustomMaterial(
            surfaceShader: surfaceShader,
            geometryModifier: geometryModifier,
            lightingModel: .lit
        )

        // Bound into the otherwise-unused `baseColor` texture slot purely as a way to hand the
        // shader raw pixels to sample — `waterSurfaceShader` does **not** use this as a base color
        // in the normal UV-mapped sense; it samples it by the reflection vector's own
        // equirectangular angle instead, to fake a real sky reflection (see that file's own
        // comment for why the previous procedural "shoreline band" approach was replaced: it
        // produced an arbitrary radial highlight pattern with no relationship to the actual sky,
        // which is what the user meant by "not reflecting the sky, random reflect highlight").
        if let url = Bundle.main.url(forResource: "sky_ibl", withExtension: "jpg"),
           let skyTexture = try? TextureResource.load(contentsOf: url, withName: "water_sky_reflection") {
            material.baseColor.texture = CustomMaterial.Texture(skyTexture)
        }

        // Real water ripple detail, per user request ("can we use free water texture instead?")
        // after repeated procedural attempts (analytic sine waves, then a fake reflection pattern)
        // kept looking visibly synthetic. `water_normal.jpg` is the well-known tileable water
        // normal map bundled in three.js's own examples (`examples/textures/waternormals.jpg`,
        // MIT-licensed repo — attribution required, same tracking convention this project already
        // applies to CC-BY assets) — used here exactly as it's used in three.js's own reference
        // water shader: sampled three times (originally twice; a third independently-scrolling/
        // tiled sample was added in a later pass, see `WaterShader.metal`), not just wired in
        // statically. Loaded with `.normal` semantic so
        // RealityKit treats its pixel data as a linear normal map, not sRGB color.
        if let url = Bundle.main.url(forResource: "water_normal", withExtension: "jpg"),
           let normalTexture = try? TextureResource.load(
               contentsOf: url,
               withName: "water_ripple_normal",
               options: .init(semantic: .normal)
           ) {
            material.normal.texture = CustomMaterial.Texture(normalTexture)
        }

        return material
    }

    private static func findModelEntity(in entity: Entity) -> ModelEntity? {
        if let model = entity as? ModelEntity {
            return model
        }
        for child in entity.children {
            if let found = findModelEntity(in: child) {
                return found
            }
        }
        return nil
    }

    private enum MaterialError: Error {
        case noMetalDevice
        case noDefaultLibrary
    }
}
