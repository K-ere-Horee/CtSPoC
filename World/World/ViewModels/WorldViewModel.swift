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

    private var rodRig: RodRigController?
    private var controllerEntity: Entity?
    private var hookEntity: ModelEntity?
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
    /// instead of as a distant dot. Snaps back to the player pose for every other phase —
    /// including `.result` and the splash-wait, so the camera returns home between bites.
    private func updateCameraFollow() {
        guard let playerCamera, let hookEntity else { return }

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

    /// Called by World's result screen when the player dismisses it after a
    /// catch, allowing the next cast.
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
        fishFight.resetForNewCast()
        setHookPhase(.idle)
        screen = .mainMenu
    }

    private func setHookPhase(_ phase: HookPhase) {
        guard hookPhase != phase else { return }
        hookPhase = phase
        Task { await send(.hookPhase(phase)) }
    }

    private func tick(deltaTime: Float) {
        updateRodPose()
        updateCameraFollow()
        rodRig?.applyLineTension(lineTension(for: hookPhase))

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
                Task { await send(.fishingEvent(.fishInterested)) }
            case .bite:
                setHookPhase(.fishOnHook)
                ensureFightDistance()
                Task { await send(.fishingEvent(.fishBite)) }
            case nil:
                break
            }
            if rodState.action == .reeling {
                reelHook(deltaTime: deltaTime)
            }
        case .result:
            break
        case .fishOnHook, .reeling:
            if rodState.action == .reeling {
                reelHook(deltaTime: deltaTime)
            } else {
                driftHookAway(deltaTime: deltaTime)
                setHookPhase(.fishOnHook)
            }

            if let failure = fishFight.updateFight(
                deltaTime: deltaTime,
                isReeling: rodState.action == .reeling,
                reelSpeed: rodState.reelSpeed,
                hookDistance: hookDistanceFromRod()
            ) {
                resolveFightFailure(failure)
            }
        }

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
        Task { await send(.fishingEvent(event)) }
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
            Task { await send(.fishingEvent(.fishEscaped)) }
        case .lineBreak:
            hookEntity?.isEnabled = false
            setHookPhase(.idle)
            Task { await send(.fishingEvent(.lineBreak)) }
        }
    }

    /// Called right when a fish bites. If the player was already reeling in
    /// during the search phase, the hook may already be within reeling's
    /// catch-distance threshold — without this, the very next `reelHook`
    /// call in the same tick would resolve an instant catch, so `hasFishOnHook`
    /// flips true then false before SwiftUI ever renders a frame and the
    /// tension meter never visibly appears. Pushes the hook back out to
    /// `fishFight.minimumFightDistance` so a real fight always happens.
    private func ensureFightDistance() {
        guard let controllerEntity, let hookEntity else { return }

        let directionToRod = controllerEntity.position - hookEntity.position
        let distance = simd_length(directionToRod)
        guard distance < fishFight.minimumFightDistance else { return }

        let awayDirection = distance > 0.0001 ? -simd_normalize(directionToRod) : SIMD3<Float>(0, 0, -1)
        hookEntity.position += awayDirection * (fishFight.minimumFightDistance - distance)
    }

    private func driftHookAway(deltaTime: Float) {
        guard let controllerEntity, let hookEntity else { return }

        let directionToRod = controllerEntity.position - hookEntity.position
        let distance = simd_length(directionToRod)
        guard distance > 0.0001 else { return }

        let awayDirection = -simd_normalize(directionToRod)
        let step = fishFight.fishPullSpeed * deltaTime
        hookEntity.position += awayDirection * step
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
            return
        }

        let tipPosition = tipEntity.position(relativeTo: nil)
        hookEntity.isEnabled = true
        hookEntity.position = tipPosition
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
        setHookPhase(.hookInWater)
        Task { await send(.fishingEvent(.hookSplash)) }
    }

    private func reelHook(deltaTime: Float) {
        guard let controllerEntity, let hookEntity else { return }

        let directionToRod = controllerEntity.position - hookEntity.position
        let distance = simd_length(directionToRod)
        guard distance > 0.12 else {
            hookEntity.isEnabled = false
            let caughtFish = fishFight.hasFishOnHook
            if caughtFish {
                fishFight.resolveCatch()
            }
            setHookPhase(caughtFish ? .result : .idle)
            if caughtFish {
                Task { await send(.fishingEvent(.catchFish)) }
            }
            return
        }

        // Tug-of-war (ADR-039): the hooked fish's pull speed is subtracted from the player's reel
        // speed, so a strong fish gains line even while the player is actively (but weakly)
        // reeling — net-negative speed moves the hook AWAY. Combined with the distance-escape
        // check in `updateFight`, weak reeling against a strong fish is now a losing strategy
        // rather than a slow guaranteed win. Empty retrieves (`fishPullSpeed` is 0 with no fish)
        // behave exactly as before.
        let playerSpeed = max(0.35, rodState.reelSpeed * reelSpeed)
        let netSpeed = playerSpeed - fishFight.fishPullSpeed
        if netSpeed >= 0 {
            let step = min(distance, netSpeed * deltaTime)
            hookEntity.position += simd_normalize(directionToRod) * step
        } else {
            hookEntity.position -= simd_normalize(directionToRod) * (-netSpeed * deltaTime)
        }

        // Only a hooked fish makes this a "fight" reel. Retrieving an empty
        // line during `.hookInWater` must stay `.hookInWater` — otherwise
        // `.reeling` here trips the `.fishOnHook`/`.reeling` tick case, whose
        // not-reeling branch unconditionally sets `.fishOnHook` next tick.
        if fishFight.hasFishOnHook {
            setHookPhase(.reeling)
        }
    }

    private func handle(_ message: NetworkMessage) {
        guard case let .state(state) = message else { return }
        let wasFishing = rodState.isFishing
        rodState = state
        if let solution = state.castSolution, state.action == .casting {
            pendingCastSolution = solution
        }
        connectionState = .streaming

        // Rod owns the session start/end boundary (ADR-038) — World's own screen just follows
        // `isFishing`'s edges instead of a World-side button.
        if state.isFishing, !wasFishing {
            screen = .playing
        } else if !state.isFishing, wasFishing {
            returnToMenu()
        }
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
