//
//  WorldViewModel.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 15/07/26.
//

import RealityKit
import _RealityKit_SwiftUI
import Shared
import SwiftUI
import Combine
import simd

@MainActor
final class WorldViewModel: ObservableObject {

    /// Per `GAMEPLAY_ARCHITECTURE_V1.md`: World owns the Main Menu, and "Return to Menu" is one
    /// of the two choices offered from the result screen. `ContentView` keeps the RealityKit
    /// scene (`content`) mounted for the whole app session regardless of `screen` — only an
    /// overlay is shown/hidden — so returning to the menu and starting again doesn't reload the
    /// environment/rod rig from disk a second time.
    enum Screen {
        case mainMenu
        case playing
    }

    @Published private(set) var screen: Screen = .mainMenu
    @Published private(set) var rodState = RodState()
    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var hookPhase: HookPhase = .idle
    /// True through the rise/freeze/settle cutscene phases (see `catchCutsceneRiseDuration` etc.)
    /// right after a catch resolves, before `ResultView` appears (ADR-045/047). `hookPhase` is
    /// already `.result` for the whole cutscene — casting/reeling stay locked exactly as before —
    /// this is purely a World-side presentation flag gating which overlay `ContentView` shows, not a
    /// new `HookPhase` case, so Shared/Rod need no changes.
    @Published private(set) var isShowingCatchCutscene = false
    @Published private(set) var lastError: String?
    @Published private(set) var fps: Double = 0
    /// Debug pair for diagnosing cast direction: where a perfectly straight-ahead cast of the
    /// same distance would have landed, vs. where this cast actually landed. Set together at
    /// splash in `simulateFlyingHook(deltaTime:)`; both `nil` until the first successful cast.
    @Published private(set) var debugPlayerFacingCoordinate: SIMD3<Float>?
    @Published private(set) var debugCastLandingCoordinate: SIMD3<Float>?
    /// Debug: the aim angle (degrees, 0 = straight ahead, + = right, - = left) at each stage of
    /// `launchHook(solution:)`, captured *before* the cone clamp so a clamped landing coordinate
    /// can't hide how far off the true unclamped angle actually is. Set together at launch.
    @Published private(set) var debugRawAimDegrees: Float?
    @Published private(set) var debugCorrectedAimDegrees: Float?

    private let transport: TransportHost

    /// Real-world-scale water plane sits at y=0; the rod is held near the dock's outer tip
    /// rather than at world origin (which is now the middle of an 80x60 m lake).
    private let waterHeight: Float = 0
    private let gravity: Float = 4.0
    /// Raised 3.6 -> 5.0 (ADR-039, "rod casting nya kurang jauh"): max-power ballistic range goes
    /// from ~13 m to ~24 m. `FishFightController.maxExpectedCastDistance` was retuned to match.
    private let castSpeed: Float = 5.0
    private let reelSpeed: Float = 3.0

    /// Half-angle (radians) of the allowed cast cone around the camera's fixed forward direction
    /// (-Z, per `makePlayerCamera()` — the camera never rotates dynamically, so this stays a
    /// constant, not a live basis vector). 135° total, so ±67.5° either side of straight ahead.
    /// A hard clamp regardless of whatever `launchHook`'s aim derivation produces upstream — the
    /// player reported the bobber's landing direction as unpredictable/unwanted ("gue masih gatau
    /// direction si yellow bobber ini kemana, tapi... ga sesuai sama apa yang gue mau") and asked
    /// for a guaranteed forward-biased limitation independent of that, rather than a further attempt
    /// to make the raw aim direction itself "correct."
    private let castConeHalfAngle: Float = 135 * .pi / 180 / 2

    /// Empirical correction rotating the rig-derived aim (see `launchHook(solution:)`) before the
    /// forward-cone clamp is applied. Originally set to 90° from the reported "bobber jumps left"
    /// symptom, but the debug angle readout (added specifically because the cone clamp was masking
    /// the true unclamped magnitude — a clamped landing coordinate can't distinguish "just past the
    /// edge" from "wildly off") measured the actual raw aim at **-174°**: not a quarter-turn off,
    /// but almost exactly **opposite** of forward. The tip-minus-root vector in `launchHook
    /// (solution:)` points nearly straight backward when the player casts forward — closer to a
    /// sign flip than an axis-mismatch nudge. 180° (`.pi`) is the corrected value; a live-measured
    /// raw angle of exactly -180° would need no further tuning, so the residual few degrees off
    /// that (-174° measured, not -180°) is left unaddressed here — check the next test's "Corrected
    /// Aim Angle" debug reading and adjust this constant directly if it isn't near 0°.
    private let aimCorrectionAngle: Float = .pi

    // MARK: - Debug: Forward Reference Ray (disabled, kept for later re-enabling)
    // /// Debug: length (meters) of the always-visible reference line drawn from `dockAnchorPosition`
    // /// straight along the camera's fixed forward (-Z), so "does the pier actually extend where the
    // /// cast math assumes forward is" can be checked by eye against the rendered dock/water, rather
    // /// than inferred from cast landing spots alone. Long enough to reach well past the dock into
    // /// open water regardless of the dock's exact length.
    // private let debugForwardRayLength: Float = 20

    /// World-space position of the first-person camera, near the dock's tip (tip itself is at
    /// `z ≈ -4.5`), facing open water — the asset repo's own validated "natural casting position"
    /// (see its CHECKPOINT.md CP41).
    ///
    /// **Not the literal tip (`z = -3.2`) any more.** That position, combined with a dead-level
    /// camera (matching the source .blend's `player_pov`, which has no pitch), put the *visible*
    /// ground/water crossover point (where `tan(halfFOV) = eyeHeight / distance` — ~3.7 m out, at
    /// this camera's 46.4°-vertical FOV and 1.6 m eye height) **past the dock's edge entirely** —
    /// every pixel of "ground" in frame was already over open water, so nothing on screen read as
    /// "standing on a dock." User feedback: "we still need to let the user know he is fishing on a
    /// dock somehow." Fixed by pulling back to `z = -1.5` (still much closer to the tip than the
    /// original shore-half `+3.2`) **and** adding `cameraPitchDownDegrees` of downward tilt so the
    /// ground/water crossover distance shrinks enough to land *before* the tip — putting a visible
    /// strip of dock decking in the lower frame, with the tip/water's edge visible beyond it, before
    /// the rod and open lake. Verified by direct screenshot, not just computed by trig (the formula
    /// is a first-order planar-ground estimate; the dock deck itself sits at a slightly different
    /// height than open water, and FOV/aspect details aren't perfectly reflected in a back-of-envelope
    /// calculation) — iterate the constants below and re-check live if the dock ever disappears from
    /// frame again after some other camera-related change.
    private let playerCameraPosition: SIMD3<Float> = [0, 2.4, -1.5]

    /// Downward camera tilt (degrees) added on top of the dead-level `player_pov` reference pose,
    /// so the dock deck is visible in frame from `playerCameraPosition` (see its doc comment) — a
    /// deliberate, small deviation from "matches the Blender camera exactly," justified by needing
    /// the player to visually read as standing on a dock, not floating on the water.
    ///
    /// **Reduced from 12° to 6°** — at 12° the sky was compressed to a thin strip at the very top
    /// of frame (~13% of the visible height in a test screenshot) while water dominated over half
    /// of it; comparing directly against the asset repo's own Blender preview render (which the
    /// user pointed to explicitly) showed a much more even split — sky roughly a third of the
    /// frame, not a sliver. 6° keeps enough tilt for the dock to still read in the lower frame
    /// (verified live, not just computed) while giving the sky room to actually read as sky.
    private let cameraPitchDownDegrees: Float = 6

    /// First-person hold position for the rod handle, in world space (not parented to the camera,
    /// so it doesn't automatically follow `cameraPitchDownDegrees` — tuned by eye to still read
    /// correctly in frame at the new camera position/tilt). Derived from the asset repo's own
    /// preview rig: in the source .blend, `rod_main` is parented directly to the `player_pov` camera
    /// with local offset (0.22, -0.45, -0.60) (x=right, y=up, z=forward). Applied here as a
    /// world-space offset from `playerCameraPosition`: world = (0, 2.4, -1.5) + (0.22, -0.45, -0.60)
    /// = (0.22, 1.95, -2.1).
    ///
    /// Kept as a fixed constant rather than driven by live Nearby Interaction distance/direction —
    /// per ADR-019/ADR-018, the rod root stays at a stable camera-relative offset; only the hook
    /// receives cast trajectory and moves through the scene.
    private let dockAnchorPosition: SIMD3<Float> = [0.22, 1.95, -2.1]

    /// Horizontal (X/Z) distance from `hookLiftTargetPosition` at which a reeled-in hook lands
    /// immediately (ADR-061) — the catch/empty-retrieve resolves in the same tick the hook crosses
    /// inside this radius, rather than climbing toward the target first. `driftHookAway` still
    /// treats this as a zone boundary for its own escaping-fish visual (full 3D drift back down
    /// toward the water once inside it, horizontal-only outside it). Outside this distance,
    /// `reelHook` stays pinned at `waterHeight` and only moves horizontally, so reeling in reads as
    /// the bobber sliding across the water toward the dock until the final, instant landing.
    private let hookLiftDistance: Float = 1.0

    /// Where `reelHook`/`driftHookAway`'s near-zone (within `hookLiftDistance`) motion and the
    /// catch/empty-retrieve resolution distance converge to — deliberately a *different* point than
    /// `dockAnchorPosition` (ADR-043). `dockAnchorPosition` is a rendering-only anchor (ADR-019: the
    /// rod root's fixed camera-relative offset) that happens to sit at `[0.22, 1.95, -2.1]`, well
    /// inside `dock_main.usdz`'s own measured footprint (X in [-2.04, 2.04], Z in [-4.5, 4.5], loaded
    /// and inspected directly via `Entity(contentsOf:).visualBounds`, not eyeballed) — using it as the
    /// hook's lift destination meant the last meter of reel-in rose straight up through the solid deck
    /// geometry at that XZ, reading as the bobber clipping through the pier (ADR-043's reported bug).
    /// `hookLiftTargetPosition` keeps the same X (0.22, still a straight pull under the rod's own
    /// centerline) and Y (1.95, still finishing at hand height) but moves Z to -4.7 — just past the
    /// mesh's measured -4.5 water-facing extreme — so the rise happens in open space in front of the
    /// dock's edge instead of inside it. Movement still visually continues toward the held rod because
    /// X/Y match `dockAnchorPosition`; only the point of closest approach in Z changes.
    private let hookLiftTargetPosition: SIMD3<Float> = [0.22, 1.95, -4.7]

    /// Amplitude/frequency of the gentle idle bob applied to a floating hook (`updateBobberFloat`)
    /// while `.hookInWater` and not being reeled in — a real bobber never sits perfectly still on
    /// the water, it rides small waves. Deliberately small/slow: this is ambient realism, not a
    /// gameplay signal (that's `interestDipAmplitude`/`interestDipFrequency` below).
    private let idleBobAmplitude: Float = 0.02
    private let idleBobFrequency: Float = 0.5
    /// Sharper, faster downward-only dip layered on top of the idle bob while
    /// `fishFight.isFishInterested` — a fish nibbling visibly tugs the float toward (and briefly
    /// under) the surface before the real bite, instead of the bite happening with zero visual
    /// warning ("celap celup," matching real bobber fishing). `-abs(sin(...))` keeps every dip
    /// downward, never lifting the float unrealistically high.
    private let interestDipAmplitude: Float = 0.06
    private let interestDipFrequency: Float = 2.0
    private var bobberBobPhase: Float = 0

    /// m/s the hook drifts sideways (world X — this scene's fixed camera forward is -Z, so world
    /// X reads as screen-space left/right, matching `fishFight.fightDirection`'s own left/right
    /// convention) while `fishFight.fightDirection` is set, in `updateFightDirectionDrift`. Purely
    /// visual — the actual counter-pull success/failure is evaluated in `FishFightController`
    /// from `RodState.roll`, not from this drift.
    private let fightDirectionLateralSpeed: Float = 0.35
    /// Cap (meters, either side of the rod's own X) on how far the juking drift can push the hook,
    /// so a long juking phase can't walk it arbitrarily far sideways.
    private let fightDirectionMaxLateralOffset: Float = 1.0

    /// Catch cutscene (ADR-045/047) timing, split into three phases so the hook visibly holds in the
    /// air instead of just arcing up and immediately back down — a single continuous arc read as too
    /// quick a blip to register as a deliberate "cutscene" moment. Total play time before `ResultView`
    /// replaces the cutscene is `catchCutsceneRiseDuration + catchCutsceneFreezeDuration +
    /// catchCutsceneSettleDuration`. All hand-picked, not tuned against a live session.
    private let catchCutsceneRiseDuration: Float = 0.35
    private let catchCutsceneFreezeDuration: Float = 0.9
    /// Retuned (ADR-071 — "jadiin 5 detik deh") to make the *real* wall-clock cutscene length exactly
    /// 5 s given `catchCutsceneRiseDuration`/`catchCutsceneFreezeDuration` above and the
    /// slow-motion dilation constants below: real time is `rise + C * (freeze + settle)` where `C`
    /// (≈2.688) is the ratio between real and story time for one dilation dip, derived by numeric
    /// integration of `1/catchCutsceneTimeDilation` over a normalized phase — solved for `settle`
    /// given a 5 s target, not hand-picked. ADR-070 originally set this to `1.85` (a flat "+1.5 s"),
    /// which produced a much longer real time than intended once the dilation multiplier was
    /// actually accounted for (~7+ s) — this value corrects that.
    private let catchCutsceneSettleDuration: Float = 0.83
    /// Peak height (m) of the placeholder catch-cutscene jump above where the hook landed — also the
    /// held height during the freeze phase.
    private let catchCutsceneJumpHeight: Float = 0.6
    /// Camera offsets from `hookEntity` during the catch cutscene (ADR-046/048). `updateCameraFollow`
    /// dollies from `catchCutsceneCameraStartOffset` to `catchCutsceneCameraEndOffset` over the whole
    /// cutscene instead of holding a single static offset — a locked-off shot on a placeholder sphere
    /// read as flat, so a slow push-in was added for a living camera move. Both are already closer and
    /// lower than the mid-fight trailing `followOffset` (`[0, 1.5, 3.0]`, ADR-039).
    private let catchCutsceneCameraStartOffset: SIMD3<Float> = [0, 1.2, 2.4]
    private let catchCutsceneCameraEndOffset: SIMD3<Float> = [0, 0.9, 1.6]

    /// Unscaled distance (m) from `caughtFishEntity`'s root to its nose/mouth tip, along the local
    /// `-Y` axis (ADR-069's orientation puts local `-Y`/head at world `+Y`, i.e. above the root once
    /// hanging vertically). Base value sourced from the mesh's own measured extent (ADR-071 — a live
    /// screenshot showed the hook sitting on/over the eye and head when using the `Head` *joint's*
    /// bind position, Y≈−0.6): the exported `.usdz`'s `extent` attribute is `[(-0.26, -1.00, -0.36),
    /// (0.26, 1.00, 0.36)]`, i.e. the actual geometry (snout/whiskers included, not just the `Head`
    /// bone's pivot) reaches to Y≈−1.0. A second live screenshot at exactly `1.0` still showed the
    /// hook slightly short of the snout tip ("dikiiittt lagi") — nudged to `1.15`, a small clearance
    /// past the measured extent rather than flush with it, matching this project's own established
    /// pattern for hook-placement margins (ADR-043's dock-clearance offset used the same "measured
    /// bound plus a small margin" approach). Used to park `hookEntity` (ADR-070 — "tali dan bomber
    /// nya masih nyangkut dengan ikan") at the fish's mouth instead of leaving it behind at the water
    /// or hidden. Scaled by `caughtFishEntity.scale` each frame, since the displayed fish size varies
    /// with the rolled catch length (ADR-064).
    private let caughtFishHeadOffset: Float = 1.15

    /// Line tension (see `lineTension(for:)`) held during the catch cutscene (ADR-070) instead of
    /// relaxing to `0` for the whole `.result` phase as before — a slack line read as disconnected
    /// from the fish right when the cutscene is trying to show it still hooked. Matches the
    /// mid-fight `.fishOnHook`/`.reeling` tension so the line still reads taut, not just "not
    /// obviously wrong." Only applied while `isShowingCatchCutscene` is true; the rest of `.result`
    /// (the `ResultView` wait) still relaxes to `0` via `lineTension(for:)`.
    private let catchCutsceneLineTension: Float = 0.8

    /// Where the new "Caught" clip's single most dramatic beat (a full-body arch, authored per the
    /// ADR-066/052 handoff) lands in the clip's own timeline — frame 44 of a 90-frame/24fps clip, per
    /// the Blender session's own report after re-authoring it. Independently re-confirmed (not just
    /// trusted from that report): the exported `.usdz`'s stage metadata is `endTimeCode = 89`,
    /// `timeCodesPerSecond = 24` (90 frames / 24fps = 3.75 s total, up from the old clip's 3.0 s).
    private let caughtFishAnimationPeakTime: Float = 1.83

    /// Playback speed for `caughtFishEntity`'s clip (ADR-067) — **derived**, not hand-picked, so
    /// `caughtFishAnimationPeakTime` lands exactly at the freeze phase's story-time midpoint
    /// (`catchCutsceneRiseDuration + catchCutsceneFreezeDuration / 2`), which is always the deepest,
    /// most sustained point of the ADR-066 slow-motion dip regardless of the dip's specific
    /// `catchCutsceneSlowMotionFactor`/`catchCutsceneSlowMotionEaseFraction` shape — a symmetric
    /// envelope's center is its deepest point no matter how steep the envelope is. Computed rather
    /// than stored specifically so a future rise/freeze retune (or another new clip) doesn't silently
    /// leave a stale hardcoded speed behind — see ADR-067 for the full derivation, including why
    /// dilation cancels out of this calculation entirely (both `cutscene.elapsed` and the animation's
    /// own playback rate are scaled by the identical per-frame dilation factor, so clip-time consumed
    /// per unit of *story* time reduces to a plain constant, independent of dilation). Supersedes
    /// ADR-065's hardcoded `1.4` — that value compensated for the *old* clip's deliberately gentle,
    /// slower-authored motion, which no longer exists now that the clip itself was replaced.
    private var catchCutsceneFishAnimationSpeed: Float {
        caughtFishAnimationPeakTime / (catchCutsceneRiseDuration + catchCutsceneFreezeDuration / 2)
    }

    /// Time-dilation factor (ADR-066) applied at the deepest point of the freeze phase's slow-motion
    /// envelope — `catchCutsceneTimeDilation(elapsed:)` eases between `1` (normal speed) and this
    /// value and back over the freeze window, rather than an abrupt on/off. `0.3` means the slowest
    /// point advances `cutscene.elapsed` (and the fish's own animation) at 30% of real time — the
    /// freeze's nominal `catchCutsceneFreezeDuration` (0.9 s of "story" time) actually takes
    /// noticeably longer in real wall-clock time while dilated, which is the intended effect: a
    /// genuine bullet-time hang on the catch, not just a longer hold at normal speed.
    private let catchCutsceneSlowMotionFactor: Float = 0.3

    /// Fraction of the freeze phase spent easing into/out of the slow-motion dip on each side (see
    /// `catchCutsceneTimeDilation(elapsed:)`) — `0.2` means the first and last 20% of the freeze
    /// window ramp between normal speed and `catchCutsceneSlowMotionFactor`, with the middle 60% held
    /// at the fully-dilated slowest point.
    private let catchCutsceneSlowMotionEaseFraction: Float = 0.2

    /// Single source for the cutscene's total run time (in "story" time — see
    /// `catchCutsceneTimeDilation(elapsed:)`; real wall-clock duration is longer while dilated) —
    /// `updateCameraFollow`'s dolly and `updateCatchCutscene`'s phase math must agree on when the
    /// cutscene ends.
    private var catchCutsceneTotalDuration: Float {
        catchCutsceneRiseDuration + catchCutsceneFreezeDuration + catchCutsceneSettleDuration
    }

    /// Tracks the in-progress catch cutscene (ADR-045): `hookEntity` arcs upward from where it
    /// landed and settles back down while `isShowingCatchCutscene` is true, instead of disappearing
    /// the instant the catch resolves. `nil` whenever no cutscene is playing.
    private struct CatchCutscene {
        let origin: SIMD3<Float>
        var elapsed: Float = 0
    }
    private var catchCutscene: CatchCutscene?

    /// Authored body length (m) of `mekong_catfish_caught.usdz` — `new-blender-project`'s
    /// `Fish06_MekongGiantCatfish/Documentation/Source_Log.md` step 4: "scaled to 2.0 m." Used only
    /// to derive `caughtFishEntity`'s cutscene display scale (ADR-064) from the actual rolled catch
    /// length, not to place/scale anything else.
    private let caughtFishAuthoredLength: Float = 2.0

    private var rodRig: RodRigController?
    private var controllerEntity: Entity?
    private var hookEntity: ModelEntity?
    /// The real animated fish shown during the catch cutscene (ADR-064) — currently always
    /// `mekong_catfish_caught.usdz` regardless of which `FishSpecies` tier was actually caught (see
    /// `beginCatchCutscene`'s doc comment for why). `nil` if the asset failed to load, in which case
    /// the cutscene silently falls back to animating `hookEntity` instead (its pre-ADR-064 behavior).
    private var caughtFishEntity: Entity?
    /// The controller for `caughtFishEntity`'s currently-playing clip (ADR-066) — kept so
    /// `updateCatchCutscene` can retarget `.speed` every frame as the slow-motion envelope moves
    /// through the freeze phase, instead of only setting it once at the start.
    private var caughtFishAnimationController: AnimationPlaybackController?
    /// Thin cylinder stretched/oriented between `hookEntity` and the live rod tip during the catch
    /// cutscene (ADR-072), standing in for `rod_line.usdz`'s own fixed-length rig, which doesn't
    /// reach the cutscene's hook position. `nil` before `makeSceneEntity()` runs.
    private var cutsceneLineEntity: ModelEntity?
    private var playerCamera: Entity?
    private var hookVelocity = SIMD3<Float>.zero
    private var castLaunchPosition = SIMD3<Float>.zero
    private var pendingCastSolution: CastSolution?
    /// Last tension band sent to Rod (ADR-039); `nil` outside a fight. See `syncTensionBand()`.
    private var lastSentTensionBand: FishFightController.TensionBand?
    private var hasStarted = false

    /// Drives the simulation from RealityKit's own per-frame scene update, with a real
    /// `event.deltaTime` — replaces a previous hand-rolled `Task.sleep(nanoseconds: 16_666_667)`
    /// loop, which ran on its own imprecise clock decoupled from the actual render cadence
    /// (`Task.sleep` has no frame-pacing guarantee and drifts under load, which read as laggy/
    /// uneven rod motion independent of any network latency). Set up once from the `RealityView`
    /// `make` closure; gated by `hasStarted` rather than torn down on `stop()`, so the same
    /// subscription survives `start()`/`stop()` cycles without needing to recreate it.
    private var frameUpdateSubscription: EventSubscription?
    private var fpsFrameCount = 0
    private var fpsElapsedTime: TimeInterval = 0

    let fishFight = FishFightController()
    let sounds = FishingSounds(sounds: SoundManager())

    init(
        transport: TransportHost
    ) {
        self.transport = transport

        transport.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.connectionState = state
                guard let self else { return }
                if state == .disconnected || state == .failed {
                    // Rod is now the sole authority for the session boundary (ADR-038), driven by
                    // `RodState.isFishing` arriving over `.state` — but a dropped connection means
                    // no more `.state` messages ever arrive, so `screen` would otherwise stay stuck
                    // on `.playing` forever with no controller left to press "End Fishing." Fail
                    // safe back to the menu instead.
                    self.returnToMenu()
                    return
                }
                guard state == .ready else { return }
                // A dropped `.hookPhase` message during a prior disconnect would otherwise leave
                // Rod stuck believing an old phase forever (MultipeerConnectivity does not retry
                // a `send()` that failed outright) — resync on every reconnect so a transient drop
                // can't permanently block casting/reeling on the Rod side.
                self.lastError = nil
                Task { await self.send(.hookPhase(self.hookPhase)) }
            }
        }
        transport.onMessage = { [weak self] message in
            Task { @MainActor in self?.handle(message) }
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        sounds.handleScreenChange(isPlaying: screen == .playing)

        Task {
            do {
                try await transport.connect()
            } catch {
                lastError = error.localizedDescription
                connectionState = .failed
            }
        }
    }

    func stop() {
        transport.disconnect()
        hasStarted = false
        sounds.stopAll()
    }

    /// Player-facing recovery action on World's Main Menu (ADR-061): the Rod<->World BLE link has
    /// been reported to wedge itself into a state that never reconnects on its own, previously
    /// only recoverable by force-quitting and relaunching World. Tears down whatever
    /// connection/scan state `transport` currently holds and starts fresh — the same
    /// disconnect-then-connect sequence `stop()`/`start()` would run across a full relaunch, just
    /// without losing `screen`/`fishFight`/progression state along with it. Safe to call from any
    /// `connectionState`, including mid-scan or mid-connect.
    func retryConnection() {
        transport.disconnect()
        Task {
            do {
                try await transport.connect()
            } catch {
                lastError = error.localizedDescription
                connectionState = .failed
            }
        }
    }

    /// The Rod this session is paired with (see `PairedDeviceStore`), for display on the Main
    /// Menu — `nil` until the first successful connection ever completes.
    var pairedDeviceName: String? { transport.pairedDeviceName }
    var hasPairedDevice: Bool { transport.hasPairedDevice }

    /// Clears the saved pairing so the next Rod discovered becomes the new paired device — the
    /// player's way to re-pair with a different phone without reinstalling or clearing app data.
    func forgetPairedDevice() {
        transport.forgetPairedDevice()
    }

    /// Resets tier-unlock progression back to Level 1 — the player's way to replay the unlock
    /// curve without reinstalling or clearing app data by hand.
    func resetProgression() {
        fishFight.resetProgression()
    }

    /// Called once from `ContentView`'s `RealityView` `make` closure. Subscribes to the scene's
    /// real per-frame update event so the simulation ticks in lockstep with actual rendering
    /// instead of a separate, imprecise timer.
    func attachFrameLoop(to content: some RealityViewContentProtocol) {
        guard frameUpdateSubscription == nil else { return }
        frameUpdateSubscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            Task { @MainActor in
                self?.advance(deltaTime: Float(event.deltaTime))
            }
        }
    }

    private func advance(deltaTime: Float) {
        updateFPS(deltaTime: TimeInterval(deltaTime))
        guard hasStarted else { return }
        tick(deltaTime: deltaTime)
    }

    /// Rolling FPS measured over a half-second window rather than a raw
    /// `1 / deltaTime` per frame, which would jump around too much to read at a glance.
    private func updateFPS(deltaTime: TimeInterval) {
        fpsFrameCount += 1
        fpsElapsedTime += deltaTime
        guard fpsElapsedTime >= 0.5 else { return }
        fps = Double(fpsFrameCount) / fpsElapsedTime
        fpsFrameCount = 0
        fpsElapsedTime = 0
    }

    func makeSceneEntity() async -> Entity {
        let root = Entity()

        let environment = await EnvironmentSceneBuilder.build()
        root.addChild(environment)

        let camera = makePlayerCamera()
        playerCamera = camera
        root.addChild(camera)

        let rig = await RodRigController.load()
        root.addChild(rig.root)
        controllerEntity = rig.root
        rodRig = rig

        let hook = ModelEntity(
            mesh: .generateSphere(radius: 0.07),
            materials: [SimpleMaterial(color: .yellow, isMetallic: false)]
        )
        hook.isEnabled = false
        hookEntity = hook
        root.addChild(hook)

        // ADR-064: loaded once up front like every other scene entity, not lazily on first catch —
        // `Entity(named:)` is async and this avoids a load stall on the player's very first catch.
        if let fish = try? await Entity(named: "mekong_catfish_caught") {
            fish.isEnabled = false
            caughtFishEntity = fish
            root.addChild(fish)
        }

        // ADR-072: a dedicated, simple line for the catch cutscene — "kalo tambahin tali pancing nya
        // bisa ga." `rod_line.usdz`'s own rig (`RodRigController.applyLineTension`) is a fixed-length
        // prop anchored at the rod tip; the cutscene's hook sits ~2.6 m further out than any mid-fight
        // distance that rig was ever meant to span, so it doesn't reach — confirmed by reading
        // `RodRigController.swift` directly (procedural bend only, no length/reach driven by code)
        // rather than guessed from the screenshot showing no line at all. A thin cylinder, stretched
        // and oriented every frame between `hookEntity` and the live rod tip, is simpler and more
        // reliable than trying to make the skinned rig stretch beyond its authored length.
        let line = ModelEntity(
            mesh: .generateCylinder(height: 1, radius: 0.012),
            materials: [SimpleMaterial(color: .white, isMetallic: false)]
        )
        line.isEnabled = false
        cutsceneLineEntity = line
        root.addChild(line)

        // root.addChild(makeDebugForwardRay())

        return root
    }

    // MARK: - Debug: Forward Reference Ray (disabled, kept for later re-enabling)
    // /// Debug: a thin, always-visible line from `dockAnchorPosition` straight along the camera's
    // /// fixed forward (-Z) — see `debugForwardRayLength`'s doc comment. `UnlitMaterial` so it reads
    // /// as a flat, unmistakable reference color regardless of scene lighting/shadow, rather than
    // /// blending into whatever's behind it.
    // private func makeDebugForwardRay() -> Entity {
    //     let ray = ModelEntity(
    //         mesh: .generateBox(size: [0.03, 0.03, debugForwardRayLength]),
    //         materials: [UnlitMaterial(color: .red)]
    //     )
    //     ray.name = "DebugForwardRay"
    //     ray.position = dockAnchorPosition + SIMD3<Float>(0, 0, -debugForwardRayLength / 2)
    //     return ray
    // }

    /// `RealityView` in non-AR ("virtual") mode has no ARKit device camera to fall back on, and
    /// provides no default first-person viewpoint of its own — without an explicit camera entity,
    /// it auto-frames the whole scene's bounding box from an arbitrary vantage point, which is what
    /// produced the "standing underwater looking up at the dock" bug. This builds that camera.
    ///
    /// Positioned at `playerCameraPosition`, facing -Z and tilted down by
    /// `cameraPitchDownDegrees` (see that constant's doc comment for why — keeping the dock deck
    /// visible in frame, not a dead-level match to the source .blend's `player_pov` any more).
    /// Verified against `dock_main.usdz`/`terrain_underwater.usdz` world-space geometry (loaded
    /// through RealityKit, not just read from the source .blend): the open-water/dock-tip side is
    /// -Z, the shore side is +Z, so -Z is "out over the lake" from any point along the dock.
    private func makePlayerCamera() -> Entity {
        let camera = PerspectiveCamera()
        camera.name = "PlayerCamera"
        camera.components.set(
            PerspectiveCameraComponent(fieldOfViewInDegrees: 46.4, fieldOfViewOrientation: .vertical)
        )

        resetCameraToPlayerPose(camera)
        return camera
    }

    private func resetCameraToPlayerPose(_ camera: Entity) {
        let pitch = cameraPitchDownDegrees * .pi / 180
        let forward = SIMD3<Float>(0, -sin(pitch), -cos(pitch))
        camera.look(
            at: playerCameraPosition + forward,
            from: playerCameraPosition,
            relativeTo: nil
        )
    }

    /// Swings the camera to trail behind and above the hook, looking straight at it. Originally a
    /// flight-only debug aid; now also active through the whole fight (`.fishOnHook`/`.reeling`,
    /// ADR-039 — "camera langsung geser lagi ke hook biar proses reel nya jadi lebih dramatis"),
    /// so the tug-of-war (fish dragging line out, player reeling it back) is watched up close
    /// instead of as a distant dot, and through the catch cutscene (ADR-046 — "butuh cameranya
    /// langsung ke bomber dan ikan yang ketangkep, biar beneran kaya cut scene") at a dedicated,
    /// slowly-dollying-in offset (ADR-048) so the jump actually reads as a cut, not just the same
    /// trailing shot. Snaps back to the player pose for every other phase — including the rest of
    /// `.result`, once the cutscene itself has ended — so the camera returns home between bites.
    private func updateCameraFollow() {
        guard let playerCamera, let hookEntity else { return }

        if isShowingCatchCutscene, let cutscene = catchCutscene {
            // Slow push-in (ADR-048): a single static offset for the whole cutscene read as a
            // locked-off, flat shot — easing from a wider start toward the tighter ADR-046 offset
            // over the cutscene's full run gives the camera its own motion, independent of the
            // hook's rise/freeze/settle.
            let t = min(cutscene.elapsed / catchCutsceneTotalDuration, 1)
            let eased = t * t * (3 - 2 * t)
            let offset = catchCutsceneCameraStartOffset
                + (catchCutsceneCameraEndOffset - catchCutsceneCameraStartOffset) * eased
            // Reads position from `cutscene.origin` + the shared height curve (ADR-064) rather than
            // `hookEntity.position` — `hookEntity` is hidden for the whole cutscene now that
            // `caughtFishEntity` plays it instead, so its position is stale/irrelevant here.
            let focusPosition = cutscene.origin
                + SIMD3<Float>(0, catchCutsceneHeight(elapsed: cutscene.elapsed), 0)
            playerCamera.look(
                at: focusPosition,
                from: focusPosition + offset,
                relativeTo: nil
            )
            return
        }

        let followsHook = hookPhase == .flying || hookPhase == .fishOnHook || hookPhase == .reeling
        guard followsHook else {
            resetCameraToPlayerPose(playerCamera)
            return
        }

        let followOffset = SIMD3<Float>(0, 1.5, 3.0)
        playerCamera.look(
            at: hookEntity.position,
            from: hookEntity.position + followOffset,
            relativeTo: nil
        )
    }

    /// Dismisses a showing result screen, allowing the next cast. Called from `handle(_:)` the
    /// instant Rod reports an armed cast (ADR-061) — World's `ResultView` no longer has its own
    /// dismiss button, since pressing "Start Casting" on Rod is now the single action that both
    /// dismisses the result and starts the next attempt.
    func continueFishing() {
        guard hookPhase == .result else { return }
        setHookPhase(.idle)
    }

    /// Reactive, not button-driven (ADR-038): called from `handle(_:)` when `RodState.isFishing`
    /// flips true/false, and as a fail-safe from `transport.onStateChange` if Rod disconnects
    /// mid-session. Unlike the old button-driven version this isn't gated to
    /// `hookPhase == .result` — the player can press "End Fishing" on Rod at any point, not just
    /// after a catch — so it resets whatever fight/hook state was in progress. Does not disconnect
    /// Rod; the transport connection is left running so starting again doesn't need to
    /// rediscover/reconnect.
    private func returnToMenu() {
        guard screen != .mainMenu else { return }
        hookVelocity = .zero
        hookEntity?.isEnabled = false
        caughtFishEntity?.isEnabled = false
        caughtFishAnimationController = nil
        cutsceneLineEntity?.isEnabled = false
        catchCutscene = nil
        isShowingCatchCutscene = false
        fishFight.resetForNewCast()
        setHookPhase(.idle)
        screen = .mainMenu
        sounds.handleScreenChange(isPlaying: false)
    }

    private func setHookPhase(_ phase: HookPhase) {
        guard hookPhase != phase else { return }
        hookPhase = phase
        sounds.handlePhaseChange(phase)
        Task { await send(.hookPhase(phase)) }
    }

    private func tick(deltaTime: Float) {
        updateRodPose()
        updateCameraFollow()
        rodRig?.applyLineTension(isShowingCatchCutscene ? catchCutsceneLineTension : lineTension(for: hookPhase))
        rodRig?.applyReelSpin(reelSpeed: rodState.reelSpeed, isReeling: rodState.action == .reeling, deltaTime: deltaTime)

        switch hookPhase {
        case .idle:
            if rodState.action == .casting {
                if let solution = pendingCastSolution {
                    launchHook(solution: solution)
                    pendingCastSolution = nil
                }
            }
        case .flying:
            simulateFlyingHook(deltaTime: deltaTime)
        case .hookInWater:
            switch fishFight.updateSearching(deltaTime: deltaTime) {
            case .interested:
                emit(.fishInterested)
            case .bite:
                setHookPhase(.fishOnHook)
                ensureFightDistance()
                emit(.fishBite)
            case nil:
                break
            }
            if rodState.action == .reeling {
                reelHook(deltaTime: deltaTime)
            } else {
                updateBobberFloat(deltaTime: deltaTime)
            }
        case .result:
            if catchCutscene != nil {
                updateCatchCutscene(deltaTime: deltaTime)
            }
        case .fishOnHook, .reeling:
            if rodState.action == .reeling {
                reelHook(deltaTime: deltaTime)
            } else {
                driftHookAway(deltaTime: deltaTime)
                setHookPhase(.fishOnHook)
            }
            updateFightDirectionDrift(deltaTime: deltaTime)

            if let failure = fishFight.updateFight(
                deltaTime: deltaTime,
                isReeling: rodState.action == .reeling,
                reelSpeed: rodState.reelSpeed,
                hookDistance: hookDistanceFromRod(),
                rodRoll: rodState.roll
            ) {
                resolveFightFailure(failure)
            }
        }

        sounds.updateReelLoop(active: rodState.action == .reeling && hookPhase != .idle && hookPhase != .flying && hookPhase != .result)
        syncTensionBand()
    }

    private func hookDistanceFromRod() -> Float {
        guard let controllerEntity, let hookEntity else { return 0 }
        return simd_length(controllerEntity.position - hookEntity.position)
    }

    /// Sends a `FishingEvent` to Rod whenever the fight's tension band changes (ADR-039), so Rod
    /// can pulse continuously at the right rhythm without World streaming raw tension. Cleared
    /// without sending when the fight ends — the fight-ending events (`fishEscaped`/`catchFish`/
    /// `lineBreak`) already stop Rod's fight haptics on their own.
    private func syncTensionBand() {
        let band = fishFight.tensionBand
        guard band != lastSentTensionBand else { return }
        lastSentTensionBand = band

        guard let band else { return }
        let event: FishingEvent = switch band {
        case .low: .reelTensionLow
        case .medium: .reelTensionMedium
        case .high: .reelTensionHigh
        }
        emit(event)
    }

    /// Both failures now reset the hook to `.idle` (a fresh cast is required) instead of
    /// `.escaped` staying `.hookInWater` — requested directly: "kalo tension kerendahan (slack),
    /// reset langsung bobber ke posisi awal (alias ga hookInWater lagi)." A slack-tension escape
    /// and a distance-spooled escape (ADR-039) both report as `.escaped`; both get the same
    /// treatment, since in either case the line/hook is no longer somewhere fishing can sensibly
    /// continue from without recasting.
    private func resolveFightFailure(_ failure: FishFightController.FightFailure) {
        switch failure {
        case .escaped:
            hookEntity?.isEnabled = false
            setHookPhase(.idle)
            emit(.fishEscaped)
        case .lineBreak:
            hookEntity?.isEnabled = false
            setHookPhase(.idle)
            emit(.lineBreak)
        }
    }

    /// Called right when a fish bites. If the player was already reeling in
    /// during the search phase, the hook may already be within reeling's
    /// catch-distance threshold — without this, the very next `reelHook`
    /// call in the same tick would resolve an instant catch, so `hasFishOnHook`
    /// flips true then false before SwiftUI ever renders a frame and the
    /// tension meter never visibly appears. Pushes the hook back out to
    /// `fishFight.minimumFightDistance` so a real fight always happens.
    /// Floats the hook while it's searching (see the doc comments on `idleBobAmplitude`/
    /// `interestDipAmplitude` for what each layer represents). Only runs while `.hookInWater` and
    /// not being actively reeled in — `reelHook` and the fight mechanics own the hook's vertical
    /// position the instant either of those takes over, and this would otherwise fight with them
    /// over `hookEntity.position.y` on the same tick.
    private func updateBobberFloat(deltaTime: Float) {
        guard let hookEntity else { return }
        bobberBobPhase += deltaTime

        let idleBob = sin(bobberBobPhase * idleBobFrequency * 2 * .pi) * idleBobAmplitude
        let interestDip = fishFight.isFishInterested
            ? -abs(sin(bobberBobPhase * interestDipFrequency * 2 * .pi)) * interestDipAmplitude
            : 0

        hookEntity.position.y = waterHeight + idleBob + interestDip
    }

    private func ensureFightDistance() {
        guard let controllerEntity, let hookEntity else { return }

        let directionToRod = controllerEntity.position - hookEntity.position
        let distance = simd_length(directionToRod)
        guard distance < fishFight.minimumFightDistance else { return }

        let awayDirection = distance > 0.0001 ? -simd_normalize(directionToRod) : SIMD3<Float>(0, 0, -1)
        hookEntity.position += awayDirection * (fishFight.minimumFightDistance - distance)
    }

    private func driftHookAway(deltaTime: Float) {
        guard let hookEntity else { return }

        let step = fishFight.fishPullSpeed * deltaTime
        let horizontalOffset = SIMD3<Float>(
            hookLiftTargetPosition.x - hookEntity.position.x,
            0,
            hookLiftTargetPosition.z - hookEntity.position.z
        )
        let horizontalDistance = simd_length(horizontalOffset)

        // Below `hookLiftDistance` the hook may already be lifted partway toward
        // `hookLiftTargetPosition` (see `reelHook`) — let it drift away in full 3D so an escaping
        // fish pulls it back down toward the water as it retreats. Otherwise stay pinned at
        // `waterHeight` and drift horizontally only, so an ignored fish drags the hook further out
        // across the water, not underneath it.
        if horizontalDistance <= hookLiftDistance {
            let directionToTarget = hookLiftTargetPosition - hookEntity.position
            guard simd_length(directionToTarget) > 0.0001 else { return }
            hookEntity.position -= simd_normalize(directionToTarget) * step
        } else {
            guard horizontalDistance > 0.0001 else { return }
            hookEntity.position -= simd_normalize(horizontalOffset) * step
            hookEntity.position.y = waterHeight
        }
    }

    /// Visually sells the fish's juke (`fishFight.fightDirection`) as a distinct sideways nudge on
    /// top of whatever `reelHook`/`driftHookAway` already did to the hook's position this tick — a
    /// small, continuous world-X drift toward the current direction, clamped to stay within
    /// `fightDirectionMaxLateralOffset` of the rod's own X so a long juking phase can't walk the
    /// hook arbitrarily far sideways. No-op whenever the juking phase isn't active.
    private func updateFightDirectionDrift(deltaTime: Float) {
        guard let hookEntity, let controllerEntity, let direction = fishFight.fightDirection else { return }

        let sign: Float = direction == .left ? -1 : 1
        let targetX = hookEntity.position.x + sign * fightDirectionLateralSpeed * deltaTime
        let minX = controllerEntity.position.x - fightDirectionMaxLateralOffset
        let maxX = controllerEntity.position.x + fightDirectionMaxLateralOffset
        hookEntity.position.x = max(minX, min(maxX, targetX))
    }

    /// Per ADR-018/ADR-019 and the calibration contract in `AGENTS.md`: the rod root stays at a
    /// fixed camera-relative offset (`dockAnchorPosition`) — Nearby Interaction distance/direction
    /// must never move it, only the hook receives cast trajectory. Orientation comes directly from
    /// `RodState.orientation`, the single renderer-facing quaternion already corrected by the
    /// Rod/Shared calibration pipeline; World must not reconstruct it from raw Euler angles or add
    /// its own smoothing/clamping on top. Raw `pitch`/`roll` remain available for the rod rig's own
    /// secondary bend visualization (`RodRigController.applyBend`), which is a supplementary flex
    /// effect layered on top of the whole-rig orientation, not the renderer orientation itself.
    private func updateRodPose() {
        guard let controllerEntity else { return }

        controllerEntity.position = dockAnchorPosition
        controllerEntity.orientation = simd_quatf(
            ix: Float(rodState.orientation.x),
            iy: Float(rodState.orientation.y),
            iz: Float(rodState.orientation.z),
            r: Float(rodState.orientation.w)
        )

        rodRig?.applyBend(pitch: rodState.pitch, roll: rodState.roll)
    }

    private func lineTension(for phase: HookPhase) -> Float {
        switch phase {
        case .idle: return 0
        case .flying: return 0.9
        case .hookInWater: return 0.3
        case .fishOnHook, .reeling: return 0.8
        case .result: return 0
        }
    }

    private func launchHook(solution: CastSolution) {
        guard
            let controllerEntity,
            let hookEntity,
            let tipEntity = rodRig?.tipEntity
        else {
            // A valid cast reaching this point with the scene not fully set up would otherwise
            // fail with zero signal — mirrors the decode-failure/dropped-message logging
            // philosophy elsewhere in the transport layer (ADR-062/063).
            #if DEBUG
            print("[CAST] launchHook rejected: scene not ready (controllerEntity=\(self.controllerEntity != nil) hookEntity=\(self.hookEntity != nil) tipEntity=\(self.rodRig?.tipEntity != nil))")
            #endif
            return
        }

        let tipPosition = tipEntity.position(relativeTo: nil)
        hookEntity.isEnabled = true
        hookEntity.position = tipPosition
        hookEntity.scale = SIMD3<Float>(repeating: 1)  // ADR-071: undo any catch-cutscene scaling
        castLaunchPosition = tipPosition
        let angle = solution.launchAngle

        // `solution.direction` is Shared's abstract Rod-frame heading, rotated from a hardcoded
        // `CastVector3.forward = (0, 0, -1)` — a constant only ever correct for the old placeholder
        // arrow mesh, whose local tip sat along -Z. `rod_main.usdz`'s bone chain rests along +Y
        // instead (see `RodRigController.rodBones`' `restTranslation`s), so reinterpreting
        // `solution.direction`'s x/z as a World-space heading pointed the hook off-axis from
        // wherever the rig visually aimed — a fixed, consistent offset, not per-cast noise. Per
        // ADR-018/019, Shared must stay mesh-agnostic, so the fix belongs here: derive the actual
        // horizontal aim from the live rig geometry at this exact cast moment — the vector from the
        // fixed `controllerEntity` root to the tip's current world position — which by construction
        // always matches wherever the rendered tip is actually pointing, independent of any rig's
        // internal rest-pose axis convention (and immune to the next rig swap breaking this again).
        let aim = tipPosition - controllerEntity.position
        let horizontalAim = SIMD3<Float>(aim.x, 0, aim.z)
        let rawHorizontal = simd_length(horizontalAim) > 0.0001
            ? simd_normalize(horizontalAim)
            : SIMD3<Float>(0, 0, -1)
        let correctedHorizontal = rotatedAroundY(rawHorizontal, by: aimCorrectionAngle)
        let horizontal = clampedToForwardCone(correctedHorizontal)

        // Captured pre-clamp: `debugCastLandingCoordinate` alone can't distinguish "just past the
        // cone edge" from "wildly off" once clamped, since both land at the same clamped boundary.
        debugRawAimDegrees = signedAngleDegrees(rawHorizontal)
        debugCorrectedAimDegrees = signedAngleDegrees(correctedHorizontal)

        let speed = castSpeed * (0.5 + (solution.power * 1.5))
        hookVelocity = horizontal * (cos(angle) * speed)
            + SIMD3<Float>(0, sin(angle) * speed, 0)

        sounds.castLaunched()
        setHookPhase(.flying)
    }

    /// Rotates a horizontal (Y=0) direction by `angle` radians around Y — positive rotates right,
    /// matching `clampedToForwardCone`'s sign convention below. Used to apply
    /// `aimCorrectionAngle`'s empirical bias fix ahead of the cone clamp.
    private func rotatedAroundY(_ direction: SIMD3<Float>, by angle: Float) -> SIMD3<Float> {
        let cosA = cos(angle)
        let sinA = sin(angle)
        return SIMD3<Float>(
            direction.x * cosA - direction.z * sinA,
            direction.y,
            direction.x * sinA + direction.z * cosA
        )
    }

    /// Clamps a horizontal (Y=0) direction into `castConeHalfAngle` of the camera's fixed forward
    /// (-Z). `atan2(x, -z)` gives the signed angle from straight-ahead (0 = forward, positive =
    /// right, negative = left, matching this scene's convention where -Z is "out over the lake");
    /// clamping that angle and rebuilding the vector is simpler and cheaper than a quaternion slerp
    /// for a single fixed reference axis.
    private func clampedToForwardCone(_ direction: SIMD3<Float>) -> SIMD3<Float> {
        let angle = atan2(direction.x, -direction.z)
        let clamped = max(-castConeHalfAngle, min(castConeHalfAngle, angle))
        return SIMD3<Float>(sin(clamped), 0, -cos(clamped))
    }

    /// Same signed-angle convention as `clampedToForwardCone` (0 = forward, + = right, - = left),
    /// in degrees, unclamped — for debug display only.
    private func signedAngleDegrees(_ direction: SIMD3<Float>) -> Float {
        atan2(direction.x, -direction.z) * 180 / .pi
    }

    private func simulateFlyingHook(deltaTime: Float) {
        guard let hookEntity else { return }

        hookVelocity.y -= gravity * deltaTime
        hookEntity.position += hookVelocity * deltaTime

        guard hookEntity.position.y <= waterHeight else { return }
        hookEntity.position.y = waterHeight
        hookVelocity = .zero
        let landingPoint = SIMD3<Float>(hookEntity.position.x, 0, hookEntity.position.z)
        let launchPoint = SIMD3<Float>(castLaunchPosition.x, 0, castLaunchPosition.z)
        let castDistance = simd_distance(landingPoint, launchPoint)

        // Debug pair: same origin, same distance, only the direction differs — so any left/right
        // deviation between the two numbers is purely angular, not confounded by how far this
        // particular cast happened to travel.
        debugCastLandingCoordinate = landingPoint
        debugPlayerFacingCoordinate = launchPoint + SIMD3<Float>(0, 0, -1) * castDistance

        fishFight.resetForNewCast(castDistance: castDistance)
        bobberBobPhase = 0
        setHookPhase(.hookInWater)
        emit(.hookSplash)
    }

    private func reelHook(deltaTime: Float) {
        guard let hookEntity else { return }

        let horizontalOffset = SIMD3<Float>(
            hookLiftTargetPosition.x - hookEntity.position.x,
            0,
            hookLiftTargetPosition.z - hookEntity.position.z
        )
        let horizontalDistance = simd_length(horizontalOffset)

        // Within `hookLiftDistance`, land the catch/empty-retrieve immediately (ADR-061) instead of
        // continuing a slow scripted climb toward `hookLiftTargetPosition` first — that climb (at
        // `dockLiftSpeed`, gated behind a further `distance3D > 0.15` closeness check) left the hook
        // visibly hanging/drifting in the air for a beat before landing, reading as the hook
        // "floating" rather than being decisively hauled in. Snapping straight to the lift target is
        // an instant, deliberate "yanked up" pop — the catch cutscene's own jump animation (ADR-045/
        // 047) still sells the "lift" for a caught fish; an empty line simply disappears at the same
        // instant. Farther out, stay pinned at `waterHeight` and move horizontally only, so reeling
        // in still reads as the bobber sliding along the water toward the dock before this point.
        if horizontalDistance <= hookLiftDistance {
            hookEntity.position = hookLiftTargetPosition
            let caughtFish = fishFight.hasFishOnHook
            if caughtFish {
                // ADR-045: keep the hook enabled and start the catch cutscene instead of
                // disabling it outright — `beginCatchCutscene` takes over its position from here.
                fishFight.resolveCatch()
                beginCatchCutscene(from: hookEntity.position)
                emit(.catchFish)
            } else {
                hookEntity.isEnabled = false
            }
            setHookPhase(caughtFish ? .result : .idle)
            return
        } else {
            // Tug-of-war (ADR-039): the hooked fish's pull speed is subtracted from the player's reel
            // speed, so a strong fish gains line even while the player is actively (but weakly)
            // reeling — net-negative speed moves the hook AWAY. Combined with the distance-escape
            // check in `updateFight`, weak reeling against a strong fish is now a losing strategy
            // rather than a slow guaranteed win. Empty retrieves (`fishPullSpeed` is 0 with no fish)
            // behave exactly as before. Only applies outside the lift zone — inside it, the catch
            // resolves immediately instead of continuing this tug-of-war math (see above).
            let playerSpeed = max(0.35, rodState.reelSpeed * reelSpeed)
            let netSpeed = playerSpeed - fishFight.fishPullSpeed
            let step = netSpeed * deltaTime

            let horizontalDirection = simd_normalize(horizontalOffset)
            if step >= 0 {
                hookEntity.position += horizontalDirection * min(horizontalDistance, step)
            } else {
                hookEntity.position -= horizontalDirection * (-step)
            }
            hookEntity.position.y = waterHeight
        }

        // Only a hooked fish makes this a "fight" reel. Retrieving an empty
        // line during `.hookInWater` must stay `.hookInWater` — otherwise
        // `.reeling` here trips the `.fishOnHook`/`.reeling` tick case, whose
        // not-reeling branch unconditionally sets `.fishOnHook` next tick.
        if fishFight.hasFishOnHook {
            setHookPhase(.reeling)
        }
    }

    /// Starts the catch cutscene (ADR-045): the final reel input that lands the fish triggers a
    /// brief "jump" moment and a "CATCH!" title, instead of the hook/fish just vanishing the instant
    /// it arrives at the dock. `hookPhase` is already `.result` by the time this is called (set by
    /// `reelHook`'s caller), so casting/reeling are locked for the whole cutscene exactly as before.
    ///
    /// ADR-064: shows `caughtFishEntity` (a real animated fish, `mekong_catfish_caught.usdz`) in the
    /// hook's place, playing that asset's baked "Caught" clip. Always the same species regardless of
    /// which `FishSpecies` tier (`fish_a`/`fish_b`/`fish_c`/`scott`) was actually rolled —
    /// `FishCatalog`'s four tiers are still placeholder data with no asset reference of their own
    /// (see its own doc comment), and only one species out of the asset repo's ten has a fully
    /// verified-good export/orientation (see `caughtFishEntity`'s doc comment). Mapping specific
    /// tiers to specific species is a content decision left for later, once more species are vetted.
    /// `caughtFishEntity`'s *display scale* does still vary with the actual rolled catch length, so
    /// the size at least tracks what `ResultView` shows next.
    ///
    /// ADR-070: `hookEntity` is **not** disabled when `caughtFishEntity` is available — it stays
    /// visible, parked at the fish's mouth (`caughtFishHeadOffset` along the fish's local `-Y`/head
    /// axis, scaled to match), so the line rigged to it still reads as physically hooked into the
    /// catch instead of the fish appearing to float free while the hook/line vanish.
    private func beginCatchCutscene(from position: SIMD3<Float>) {
        if let caughtFishEntity {
            caughtFishEntity.isEnabled = true
            caughtFishEntity.position = position
            caughtFishEntity.orientation = catchCutsceneFishOrientation
            let lengthMeters = Float((fishFight.lastCatchResult?.length ?? 100) / 100)
            let scale = max(lengthMeters / caughtFishAuthoredLength, 0.35)
            caughtFishEntity.scale = SIMD3<Float>(repeating: scale)
            // ADR-071: also scales the hook sphere itself (fixed-size otherwise, unlike the fish) —
            // a live screenshot on a small catch showed a full-size hook dwarfing the scaled-down
            // fish's head, part of the reported "masih agak broken" look. Reset to 1 in `launchHook`
            // for the next cast.
            hookEntity?.scale = SIMD3<Float>(repeating: scale)
            let hookPosition = position + SIMD3<Float>(0, caughtFishHeadOffset * scale, 0)
            hookEntity?.position = hookPosition
            updateCutsceneLine(from: hookPosition)
            if let clip = caughtFishEntity.availableAnimations.first {
                // Speed is derived, not artistic (ADR-067 — see `catchCutsceneFishAnimationSpeed`'s
                // own doc comment): this clip was re-authored in Blender (ADR-066/052 handoff) to
                // already be violent/"ngamuk" on its own terms, so the playback rate here exists
                // purely to land its authored peak beat inside the slow-motion dip, not to
                // compensate for a gentle source clip the way ADR-065's old `1.4` did. Kept as
                // `caughtFishAnimationController` so `updateCatchCutscene` can retarget `.speed`
                // again once the slow-motion envelope (ADR-066) starts moving through the freeze
                // phase.
                let controller = caughtFishEntity.playAnimation(clip)
                controller.speed = catchCutsceneFishAnimationSpeed
                caughtFishAnimationController = controller
            }
        }

        catchCutscene = CatchCutscene(origin: position)
        isShowingCatchCutscene = true
    }

    /// Height above `cutscene.origin` at `elapsed` seconds into the catch cutscene (ADR-045/047) —
    /// shared by `updateCatchCutscene` (moves whichever entity is playing the cutscene) and
    /// `updateCameraFollow`'s cutscene branch (ADR-048's push-in needs the same focus point), so the
    /// two can't drift out of sync. Three phases: ease up to `catchCutsceneJumpHeight` over
    /// `catchCutsceneRiseDuration`, hold there for `catchCutsceneFreezeDuration` (ADR-047 — a
    /// continuous up-then-down arc alone read as too quick a blip to register as a deliberate
    /// "cutscene" moment), then ease back down over `catchCutsceneSettleDuration`.
    private func catchCutsceneHeight(elapsed: Float) -> Float {
        let riseEnd = catchCutsceneRiseDuration
        let freezeEnd = riseEnd + catchCutsceneFreezeDuration

        if elapsed < riseEnd {
            let t = elapsed / catchCutsceneRiseDuration
            return sin(t * .pi / 2) * catchCutsceneJumpHeight
        } else if elapsed < freezeEnd {
            return catchCutsceneJumpHeight
        } else {
            let t = min((elapsed - freezeEnd) / catchCutsceneSettleDuration, 1)
            return max(cos(t * .pi / 2) * catchCutsceneJumpHeight, 0)
        }
    }

    /// Fixed vertical "hooked and hanging" pose for `caughtFishEntity` (ADR-069 — ADR-068's
    /// horizontal `+X`-facing pose was seen live and reported as "ikannya kaya berenang... harusnya
    /// kepala nya [di atas], vertical" — the fish read as lying flat like an ordinary swim cycle, not
    /// like a fish hanging from the line by its mouth. Reverses ADR-068's direction: head points
    /// *up*, not sideways). Head (local `-Y`, per the axis confirmation in `fishOrientation
    /// (facing:)`'s doc comment) maps to world `+Y`; the fish's local `X` (lateral/width — its
    /// "thin" dimension) maps to world `Z`, so the camera — which always looks roughly along `-Z`,
    /// same fixed geometry ADR-068 relied on — sees the fish's broadside silhouette (length +
    /// height) while it hangs vertically, not a foreshortened head-on view.
    ///
    /// Built directly from target basis vectors, not `fishOrientation(facing:)`'s two-step
    /// shortest-arc-plus-roll-correction construction — that function's roll step is degenerate when
    /// the facing direction *is* world-up (no distinct "desired up" left to correct toward once
    /// forward and up are the same vector), so a direct rotation-matrix build sidesteps the issue
    /// and gives explicit control over the roll instead of leaving it arbitrary.
    private var catchCutsceneFishOrientation: simd_quatf {
        let localXTarget = SIMD3<Float>(0, 0, -1)   // fish's lateral/width axis -> world -Z
        let localYTarget = SIMD3<Float>(0, -1, 0)   // fish's body axis -> world -Y (head, at local -Y, ends up at world +Y)
        // Dorsal (local Z) target computed, not guessed, so the rotation stays proper or (no
        // mirroring) — cross product of the two chosen columns, matching this rig's right-handed
        // local axes (confirmed via `upAxis = "Z"`, a direct Blender-convention export).
        let localZTarget = simd_cross(localXTarget, localYTarget)
        return simd_quatf(simd_float3x3(columns: (localXTarget, localYTarget, localZTarget)))
    }

    /// Builds the world-space rotation for `mekong_catfish_caught.usdz` given a desired head
    /// direction (ADR-065 — "orientasi nya ngikuti arah pancing," the fish should face the rod/line
    /// direction instead of sitting at its identity bind-pose rotation the whole cutscene). The
    /// asset's local axes were confirmed by reading its `bindTransforms` directly (`unzip`+`usdcat`
    /// on the copied `.usdz`, not assumed from the source repo's Blender-side notes, which describe
    /// pre-export space and don't necessarily survive export unchanged): body length runs along
    /// local Y (head at Y≈−0.6, tail/caudal fin at Y≈+0.75), dorsal-ventral runs along local Z
    /// (`Dorsal_Fin` at Z≈+0.1, `Anal_Fin` at Z≈−0.1) — this file's `upAxis = "Z"`, i.e. it's a
    /// direct Blender-convention USD export, not glTF's Y-up-converted axis layout.
    ///
    /// Two-step construction rather than a single basis-matrix build, to sidestep handedness
    /// mistakes: first rotate local head (`-Y`) to `forward` via the shortest-arc rotation
    /// (`simd_quatf(from:to:)`), which leaves an arbitrary roll around that axis; then correct the
    /// roll so the dorsal fin (local `+Z`) ends up as close to world-up as geometrically possible,
    /// instead of whatever roll the shortest-arc step happened to produce — otherwise the fish can
    /// end up sideways or upside down while still technically "facing" the right direction.
    private func fishOrientation(facing forward: SIMD3<Float>) -> simd_quatf {
        guard simd_length(forward) > 0.0001 else { return simd_quatf(angle: 0, axis: [0, 1, 0]) }
        let forwardDirection = simd_normalize(forward)

        let headAxis = SIMD3<Float>(0, -1, 0)
        let dorsalAxis = SIMD3<Float>(0, 0, 1)
        let alignHead = simd_quatf(from: headAxis, to: forwardDirection)

        let rotatedDorsal = alignHead.act(dorsalAxis)
        let worldUp = SIMD3<Float>(0, 1, 0)
        let desiredUp = worldUp - forwardDirection * simd_dot(worldUp, forwardDirection)
        let currentUp = rotatedDorsal - forwardDirection * simd_dot(rotatedDorsal, forwardDirection)
        guard simd_length(desiredUp) > 0.0001, simd_length(currentUp) > 0.0001 else { return alignHead }

        let d = simd_normalize(desiredUp)
        let c = simd_normalize(currentUp)
        let rollAngle = atan2(simd_dot(simd_cross(c, d), forwardDirection), simd_dot(c, d))
        let roll = simd_quatf(angle: rollAngle, axis: forwardDirection)
        return roll * alignHead
    }

    /// Stretches/orients `cutsceneLineEntity` (ADR-072 — "kalo tambahin tali pancing nya bisa ga")
    /// to span from `hookPosition` to the live rod tip (`rodRig.tipEntity`, falling back to
    /// `controllerEntity` if the rig isn't loaded), called every frame the cutscene is active so it
    /// tracks both the hook and any live rod movement. Disables itself if there's no rod reference
    /// or the two points are degenerately close, rather than rendering a zero-length/undefined line.
    private func updateCutsceneLine(from hookPosition: SIMD3<Float>) {
        guard let cutsceneLineEntity else { return }
        guard let rodPoint = rodRig?.tipEntity?.position(relativeTo: nil) ?? controllerEntity?.position else {
            cutsceneLineEntity.isEnabled = false
            return
        }

        let delta = rodPoint - hookPosition
        let length = simd_length(delta)
        guard length > 0.01 else {
            cutsceneLineEntity.isEnabled = false
            return
        }

        cutsceneLineEntity.isEnabled = true
        cutsceneLineEntity.position = (hookPosition + rodPoint) / 2
        // The base cylinder mesh (`generateCylinder(height: 1, ...)`) runs along local Y, so scaling
        // just that axis stretches it to the measured distance without distorting its radius.
        cutsceneLineEntity.scale = SIMD3<Float>(1, length, 1)
        cutsceneLineEntity.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(delta))
    }

    /// Real-time-to-"story"-time dilation factor at `elapsed` seconds of story time into the
    /// cutscene. `1` (normal speed) during the rise phase; inside the freeze phase (ADR-066 — "ada
    /// slowmotion ketika di cut scene ketangkep, jadi beneran kaya game mancing") and, separately,
    /// inside the settle phase (ADR-070 — "ketika cut scene catch udah mau beres, tambahin slow
    /// motion ikan nya," a second dip right as the cutscene is about to finish), eases down to
    /// `catchCutsceneSlowMotionFactor` over the first `catchCutsceneSlowMotionEaseFraction` of
    /// *that* phase's own window, holds there through the middle, then eases back up to `1` over the
    /// same fraction at the end of that phase — an abrupt on/off at a phase boundary would read as a
    /// jump cut in and out of bullet-time rather than a deliberate slow-down/speed-up. Both dips
    /// reuse the same shape/constants rather than each having their own, for a consistent feel.
    private func catchCutsceneTimeDilation(elapsed: Float) -> Float {
        let riseEnd = catchCutsceneRiseDuration
        let freezeEnd = riseEnd + catchCutsceneFreezeDuration
        let settleEnd = freezeEnd + catchCutsceneSettleDuration

        let phaseStart: Float
        let phaseDuration: Float
        if elapsed >= riseEnd, elapsed < freezeEnd {
            phaseStart = riseEnd
            phaseDuration = catchCutsceneFreezeDuration
        } else if elapsed >= freezeEnd, elapsed < settleEnd {
            phaseStart = freezeEnd
            phaseDuration = catchCutsceneSettleDuration
        } else {
            return 1
        }

        let phaseProgress = (elapsed - phaseStart) / phaseDuration
        let rampIn = min(phaseProgress / catchCutsceneSlowMotionEaseFraction, 1)
        let rampOut = min((1 - phaseProgress) / catchCutsceneSlowMotionEaseFraction, 1)
        let envelope = min(rampIn, rampOut)
        return 1 - envelope * (1 - catchCutsceneSlowMotionFactor)
    }

    /// Drives whichever entity is standing in for the catch cutscene (ADR-045/047/049) through the
    /// `catchCutsceneHeight(elapsed:)` motion at the XZ it already arrived at. Prefers
    /// `caughtFishEntity` (the real animated fish, ADR-064); falls back to the placeholder
    /// `hookEntity` sphere if the asset failed to load, so the cutscene still plays *something*
    /// rather than nothing. `cutscene.elapsed` (the "story clock") now advances at
    /// `deltaTime * catchCutsceneTimeDilation(elapsed:)` (ADR-066/070) rather than raw `deltaTime` —
    /// the fish's own animation is retargeted to the same dilation each frame, so the position/camera
    /// motion and the struggle animation all visibly slow down and speed back up together, instead
    /// of only one of them.
    private func updateCatchCutscene(deltaTime: Float) {
        guard var cutscene = catchCutscene else { return }

        let dilation = catchCutsceneTimeDilation(elapsed: cutscene.elapsed)
        cutscene.elapsed += deltaTime * dilation
        caughtFishAnimationController?.speed = catchCutsceneFishAnimationSpeed * dilation

        let position = cutscene.origin
            + SIMD3<Float>(0, catchCutsceneHeight(elapsed: cutscene.elapsed), 0)

        if let caughtFishEntity, caughtFishEntity.isEnabled {
            caughtFishEntity.position = position
            caughtFishEntity.orientation = catchCutsceneFishOrientation
            // ADR-070: keeps the hook/line parked at the fish's mouth every frame, not just at the
            // cutscene's start, so it tracks the fish through the whole rise/freeze/settle motion.
            let hookPosition = position + SIMD3<Float>(0, caughtFishHeadOffset * caughtFishEntity.scale.y, 0)
            hookEntity?.position = hookPosition
            updateCutsceneLine(from: hookPosition)
        } else {
            hookEntity?.position = position
            updateCutsceneLine(from: position)
        }

        guard cutscene.elapsed >= catchCutsceneTotalDuration else {
            catchCutscene = cutscene
            return
        }

        catchCutscene = nil
        hookEntity?.isEnabled = false
        caughtFishEntity?.isEnabled = false
        caughtFishAnimationController = nil
        cutsceneLineEntity?.isEnabled = false
        isShowingCatchCutscene = false
    }

    private func handle(_ message: NetworkMessage) {
        guard case let .state(state) = message else { return }
        let wasFishing = rodState.isFishing
        rodState = state
        if let solution = state.castSolution, state.action == .casting {
            pendingCastSolution = solution
        }
        // ADR-061: an armed cast (the player pressed "Start Casting" on Rod) dismisses a showing
        // result screen on its own, standing in for the removed World-side "Continue Fishing"
        // button — `continueFishing()`'s own `hookPhase == .result` guard makes this a no-op once
        // already dismissed, so no extra bookkeeping is needed to fire this only once.
        if state.isCastingArmed {
            continueFishing()
        }
        connectionState = .streaming

        // Rod owns the session start/end boundary (ADR-038) — World's own screen just follows
        // `isFishing`'s edges instead of a World-side button.
        if state.isFishing, !wasFishing {
            screen = .playing
            sounds.handleScreenChange(isPlaying: true)
        } else if !state.isFishing, wasFishing {
            returnToMenu()
        }
    }

    /// Single funnel for every World-emitted `FishingEvent` — plays its sound and transmits it to
    /// Rod together, so sound and transport can never drift apart (ADR-040).
    private func emit(_ event: FishingEvent) {
        sounds.handle(event)
        Task { await send(.fishingEvent(event)) }
    }

    private func send(_ message: NetworkMessage) async {
        do {
            try await transport.send(message)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
