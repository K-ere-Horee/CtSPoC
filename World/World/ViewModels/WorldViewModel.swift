//
//  WorldViewModel.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 15/07/26.
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
    private var pendingCastSolution: CastSolution?
    private var simulationTask: Task<Void, Never>?
    private var hasStarted = false

    init(
        transport: TransportHost
    ) {
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

    private func makeArrow() -> Entity {

        let root = Entity()

        let shaft = ModelEntity(
            mesh: .generateBox(size: [0.1, 0.1, 1.0]),
            materials: [
                SimpleMaterial(color: .green, isMetallic: false)
            ]
        )

        shaft.position = [0, 0, -0.175]

        let head = ModelEntity(
            mesh: .generateCone(
                height: 0.08,
                radius: 0.04
            ),
            materials: [
                SimpleMaterial(color: .red, isMetallic: false)
            ]
        )

        // cone RealityKit default menghadap +Y
        head.orientation = simd_quatf(
            angle: -.pi / 2,
            axis: [1,0,0]
        )

        let tip = Entity()
        tip.name = "Tip"

        head.position = [0, 0, -0.72]
        tip.position = [0, 0, -0.76]

        root.addChild(shaft)
        root.addChild(head)
        root.addChild(tip)

        return root
    }

    func makeSceneEntity() async -> Entity {

        let water = ModelEntity(
            mesh: .generatePlane(width: 6, depth: 6),
            materials: [SimpleMaterial(color: .blue, isMetallic: false)]
        )
        water.position = [0, waterHeight, 0]

        let root = Entity()
        let rodRoot = Entity()
        let rod = makeArrow()
        rod.position = [0, 0, -1]

        let hook = ModelEntity(
            mesh: .generateSphere(radius: 0.035),
            materials: [SimpleMaterial(color: .yellow, isMetallic: false)]
        )
        hook.isEnabled = false

        controllerEntity = rodRoot
        rodModel = rod
        updateModelOrientation()
        hookEntity = hook

        rodRoot.addChild(rod)

        root.addChild(rodRoot)
        root.addChild(hook)
        root.addChild(water)

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
                if let solution = pendingCastSolution {
                    launchHook(solution: solution)
                    pendingCastSolution = nil
                }
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

        controllerEntity.orientation = simd_quatf(
            ix: Float(rodState.orientation.x),
            iy: Float(rodState.orientation.y),
            iz: Float(rodState.orientation.z),
            r: Float(rodState.orientation.w)
        )
    }

    private func launchHook(solution: CastSolution) {
        guard
            let controllerEntity,
            let rodModel,
            let hookEntity,
            let tip = rodModel.findEntity(named: "Tip")
        else {
            return
        }

        let tipPosition = tip.position(relativeTo: nil)
        let rodOrigin = controllerEntity.position(relativeTo: nil)

        hookEntity.isEnabled = true
        hookEntity.position = tipPosition
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
        if let solution = state.castSolution, state.action == .casting {
            pendingCastSolution = solution
        }
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
