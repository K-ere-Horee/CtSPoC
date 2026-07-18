//
//  WorldViewModel.swift
//  World
//

import RealityKit
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
    private let dockAnchorPosition: SIMD3<Float> = [0.22, 1.95, -2.1]

    /// Exponential smoothing factor (0 = frozen, 1 = no smoothing) applied to every live field of
    /// `RodState` before it drives the rod's pose. Raw CoreMotion attitude/NI distance-direction
    /// data carries small per-sample sensor noise; applying it directly to the rig every frame
    /// made the rod visibly tremble ("tingle"), most noticeably at the tip, where `applyBend`
    /// amplifies pitch/roll up to full weight. Blending a fraction of each new sample into a
    /// running average removes that high-frequency jitter while still tracking real motion within
    /// a handful of frames (~5 frames to settle at 60 fps).
    private let motionSmoothing: Float = 0.2
    private var smoothedRodPose = SmoothedRodPose()

    /// Hard cap (radians) on how far the whole rod rig visually tilts/turns from its resting
    /// pose. `RodMotionInterpreter.interpret()` (Shared/Gameplay/RodMotionInterpreter.swift) only
    /// returns pitch/roll/yaw *relative to the calibrated idle pose* once `MotionProfile.isComplete`
    /// — which defaults to `false` until the Rod app's 3-step idle/cast/reel calibration flow has
    /// been run (`Shared/Sources/Shared/Gameplay/MotionProfile.swift`). Until then it falls back to
    /// the *raw, absolute* device attitude, which can be any value depending on how the phone
    /// happens to be oriented in space — nothing like a natural rod-holding gesture. Clamping the
    /// rig's total tilt keeps the held rod on-screen and visually sane in both cases, rather than
    /// snapping to an arbitrary, uncontrolled orientation when the controller isn't calibrated.
    private let maxRigTiltAngle: Float = 0.6

    private var rodRig: RodRigController?
    private var controllerEntity: Entity?
    private var hookEntity: ModelEntity?
    private var hookVelocity = SIMD3<Float>.zero
    private var simulationTask: Task<Void, Never>?
    private var hasStarted = false

    init(transport: TransportHost = TransportHost()) {
        self.transport = transport

        transport.onStateChange = { [weak self] state in
            Task { @MainActor in self?.connectionState = state }
        }
        transport.onMessage = { [weak self] message in
            Task { @MainActor in self?.handle(message) }
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        startSimulation()

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
        simulationTask?.cancel()
        simulationTask = nil
        transport.disconnect()
        hasStarted = false
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
        root.addChild(hook)
        hookEntity = hook

        return root
    }

    func updateScene() {
        updateRodPose()
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

    private func setHookPhase(_ phase: HookPhase) {
        guard hookPhase != phase else { return }
        hookPhase = phase
        Task { await send(.hookPhase(phase)) }
    }

    private func startSimulation() {
        simulationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_666_667)
                self?.tick(deltaTime: 1.0 / 60.0)
            }
        }
    }

    private func tick(deltaTime: Float) {
        updateRodPose()
        rodRig?.applyLineTension(lineTension(for: hookPhase))

        switch hookPhase {
        case .idle:
            if rodState.action == .casting {
                launchHook()
            }
        case .flying:
            simulateFlyingHook(deltaTime: deltaTime)
        case .hookInWater:
            if rodState.action == .reeling {
                reelHook(deltaTime: deltaTime)
            }
        case .reeling:
            if rodState.action == .reeling {
                reelHook(deltaTime: deltaTime)
            } else {
                setHookPhase(.hookInWater)
            }
        }
    }

    private func updateRodPose() {
        guard let controllerEntity else { return }

        smoothedRodPose.update(toward: rodState, factor: motionSmoothing)

        let distance = smoothedRodPose.distance
        controllerEntity.position = dockAnchorPosition + SIMD3<Float>(
            smoothedRodPose.directionX * distance,
            smoothedRodPose.directionY * distance,
            -abs(smoothedRodPose.directionZ * distance)
        )

        let clampedPitch = clampedRigAngle(Float(smoothedRodPose.pitch))
        let clampedRoll = clampedRigAngle(Float(smoothedRodPose.roll))
        let clampedYaw = clampedRigAngle(Float(smoothedRodPose.yaw))

        let yaw = simd_quatf(angle: clampedYaw, axis: [0, 1, 0])
        let pitch = simd_quatf(angle: clampedPitch, axis: [1, 0, 0])
        let roll = simd_quatf(angle: clampedRoll, axis: [0, 0, 1])
        controllerEntity.orientation = yaw * pitch * roll

        rodRig?.applyBend(pitch: Double(clampedPitch), roll: Double(clampedRoll))
    }

    private func clampedRigAngle(_ angle: Float) -> Float {
        max(-maxRigTiltAngle, min(maxRigTiltAngle, angle))
    }

    private func lineTension(for phase: HookPhase) -> Float {
        switch phase {
        case .idle: return 0
        case .flying: return 0.9
        case .hookInWater: return 0.3
        case .reeling: return 0.8
        }
    }

    private func launchHook() {
        guard let controllerEntity, let hookEntity else { return }

        let forward = simd_normalize(simd_act(
            controllerEntity.orientation,
            SIMD3<Float>(0, 0, -1)
        ))
        hookEntity.isEnabled = true
        hookEntity.position = controllerEntity.position + forward * 0.18
        hookVelocity = forward * castSpeed + SIMD3<Float>(0, 0.9, 0)
        setHookPhase(.flying)
    }

    private func simulateFlyingHook(deltaTime: Float) {
        guard let hookEntity else { return }

        hookVelocity.y -= gravity * deltaTime
        hookEntity.position += hookVelocity * deltaTime

        guard hookEntity.position.y <= waterHeight else { return }
        hookEntity.position.y = waterHeight
        hookVelocity = .zero
        setHookPhase(.hookInWater)
        Task { await send(.fishingEvent(.hookSplash)) }
    }

    private func reelHook(deltaTime: Float) {
        guard let controllerEntity, let hookEntity else { return }

        let directionToRod = controllerEntity.position - hookEntity.position
        let distance = simd_length(directionToRod)
        guard distance > 0.12 else {
            hookEntity.isEnabled = false
            setHookPhase(.idle)
            return
        }

        let speed = max(0.35, rodState.reelSpeed * reelSpeed)
        let step = min(distance, speed * deltaTime)
        hookEntity.position += simd_normalize(directionToRod) * step
        setHookPhase(.reeling)
    }

    private func handle(_ message: NetworkMessage) {
        guard case let .state(state) = message else { return }
        rodState = state
        connectionState = .streaming
    }

    private func send(_ message: NetworkMessage) async {
        do {
            try await transport.send(message)
        } catch {
            lastError = error.localizedDescription
        }
    }
}

/// Running exponential-smoothed copy of `RodState`'s live-streamed pose fields. Defaults match
/// `RodState`'s own fallback values so the first frame (before any smoothing has accumulated)
/// behaves the same as reading `rodState` directly.
private struct SmoothedRodPose {
    var pitch: Double = 0
    var roll: Double = 0
    var yaw: Double = 0
    var directionX: Float = 0
    var directionY: Float = 0
    var directionZ: Float = -0.5
    var distance: Float = 0.5

    /// Blends a `factor` fraction of `state`'s current values into the running average — a
    /// standard one-pole low-pass filter, applied once per frame regardless of packet rate.
    mutating func update(toward state: RodState, factor: Float) {
        let doubleFactor = Double(factor)
        pitch += (state.pitch - pitch) * doubleFactor
        roll += (state.roll - roll) * doubleFactor
        yaw += (state.yaw - yaw) * doubleFactor
        directionX += ((state.directionX ?? 0) - directionX) * factor
        directionY += ((state.directionY ?? 0) - directionY) * factor
        directionZ += ((state.directionZ ?? -0.5) - directionZ) * factor
        distance += ((state.distance ?? 0.5) - distance) * factor
    }
}
