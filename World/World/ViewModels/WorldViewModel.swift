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

    @Published var modelPitch: Float = .pi
    @Published var modelYaw: Float = 0
    @Published var modelRoll: Float = 0

    private var rodModel: Entity?

    private let transport: TransportHost
    private let waterHeight: Float = -0.8
    private let gravity: Float = 2.2
    private let castSpeed: Float = 2.4
    private let reelSpeed: Float = 3.0

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

        let water = ModelEntity(
            mesh: .generatePlane(width: 6, depth: 6),
            materials: [SimpleMaterial(color: .blue, isMetallic: false)]
        )
        water.position = [0, waterHeight, 0]
        root.addChild(water)

        let rodRoot = Entity()
        let rod = await loadRodEntity()
        rodRoot.addChild(rod)
        root.addChild(rodRoot)
        controllerEntity = rodRoot
        rodModel = rod
        updateModelOrientation()

        let hook = ModelEntity(
            mesh: .generateSphere(radius: 0.035),
            materials: [SimpleMaterial(color: .yellow, isMetallic: false)]
        )
        hook.isEnabled = false
        root.addChild(hook)
        hookEntity = hook

        return root
    }

    func updateModelOrientation() {
        guard let rod = rodModel else { return }

        rod.orientation =
            simd_quatf(angle: modelRoll, axis: [0,0,1]) *
            simd_quatf(angle: modelYaw, axis: [0,1,0]) *
            simd_quatf(angle: modelPitch, axis: [1,0,0])
    }

    func updateScene() {
        updateRodPose()
    }

    private func setHookPhase(_ phase: HookPhase) {
        guard hookPhase != phase else { return }
        hookPhase = phase
        Task { await send(.hookPhase(phase)) }
    }

    private func loadRodEntity() async -> Entity {
        do {
            let entity = try await ModelEntity(named: "Rod")

            entity.scale = .one
            return entity
        } catch {
            lastError = "Failed loading Rod.usdz: \(error.localizedDescription)"
            return ModelEntity(
                mesh: .generateBox(size: 0.18),
                materials: [SimpleMaterial(color: .red, isMetallic: false)]
            )
        }
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

        let x = rodState.directionX ?? 0
        let y = rodState.directionY ?? 0
        let z = rodState.directionZ ?? -0.5
        let distance = rodState.distance ?? 0.5
        controllerEntity.position = [x * distance, y * distance, -abs(z * distance)]

        let yaw = simd_quatf(angle: Float(rodState.yaw), axis: [0, 1, 0])
        let pitch = simd_quatf(angle: Float(rodState.pitch), axis: [1, 0, 0])
        let roll = simd_quatf(angle: Float(rodState.roll), axis: [0, 0, 1])
        controllerEntity.orientation = yaw * pitch * roll
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
