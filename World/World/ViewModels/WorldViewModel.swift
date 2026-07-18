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

    @Published private(set) var rodState = RodState()
    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var hookPhase: HookPhase = .idle
    @Published private(set) var lastError: String?
    @Published private(set) var fps: Double = 0

    private let transport: TransportHost

    /// Real-world-scale water plane sits at y=0; the rod is held near the dock's outer tip
    /// rather than at world origin (which is now the middle of an 80x60 m lake).
    private let waterHeight: Float = 0
    private let gravity: Float = 4.0
    private let castSpeed: Float = 3.6
    private let reelSpeed: Float = 3.0

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
    private var hookVelocity = SIMD3<Float>.zero
    private var castLaunchPosition = SIMD3<Float>.zero
    private var pendingCastSolution: CastSolution?
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
                guard let self, state == .ready else { return }
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

        root.addChild(makePlayerCamera())

        let rig = await RodRigController.load()
        root.addChild(rig.root)
        controllerEntity = rig.root
        rodRig = rig

        let hook = ModelEntity(
            mesh: .generateSphere(radius: 0.035),
            materials: [SimpleMaterial(color: .yellow, isMetallic: false)]
        )
        hook.isEnabled = false
        hookEntity = hook
        root.addChild(hook)

        return root
    }

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

        let pitch = cameraPitchDownDegrees * .pi / 180
        let forward = SIMD3<Float>(0, -sin(pitch), -cos(pitch))
        camera.look(
            at: playerCameraPosition + forward,
            from: playerCameraPosition,
            relativeTo: nil
        )
        return camera
    }

    /// Called by World's result screen when the player dismisses it after a
    /// catch, allowing the next cast.
    func continueFishing() {
        guard hookPhase == .result else { return }
        setHookPhase(.idle)
    }

    private func setHookPhase(_ phase: HookPhase) {
        guard hookPhase != phase else { return }
        hookPhase = phase
        Task { await send(.hookPhase(phase)) }
    }

    private func tick(deltaTime: Float) {
        updateRodPose()
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
                reelSpeed: rodState.reelSpeed
            ) {
                resolveFightFailure(failure)
            }
        }
    }

    private func resolveFightFailure(_ failure: FishFightController.FightFailure) {
        switch failure {
        case .escaped:
            setHookPhase(.hookInWater)
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
        let horizontal = SIMD3<Float>(solution.direction.x, 0, solution.direction.z)
        let speed = castSpeed * (0.5 + (solution.power * 1.5))
        hookVelocity = horizontal * (cos(angle) * speed)
            + SIMD3<Float>(0, sin(angle) * speed, 0)

        setHookPhase(.flying)
    }

    private func simulateFlyingHook(deltaTime: Float) {
        guard let hookEntity else { return }

        hookVelocity.y -= gravity * deltaTime
        hookEntity.position += hookVelocity * deltaTime

        guard hookEntity.position.y <= waterHeight else { return }
        hookEntity.position.y = waterHeight
        hookVelocity = .zero
        let castDistance = simd_distance(
            SIMD3(hookEntity.position.x, 0, hookEntity.position.z),
            SIMD3(castLaunchPosition.x, 0, castLaunchPosition.z)
        )
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

        let speed = max(0.35, rodState.reelSpeed * reelSpeed)
        let step = min(distance, speed * deltaTime)
        hookEntity.position += simd_normalize(directionToRod) * step

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
        rodState = state
        if let solution = state.castSolution, state.action == .casting {
            pendingCastSolution = solution
        }
        connectionState = .streaming
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
