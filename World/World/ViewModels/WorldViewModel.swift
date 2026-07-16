//
//  WorldViewModel.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import RealityKit
import SwiftUI
import Shared
import Combine
import simd

@MainActor
final class WorldViewModel: ObservableObject {

    @Published private(set) var rodState = RodState()
    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var lastError: String?

    private let transport: TransportHost
    private var controllerEntity: ModelEntity?
    private var hasStarted = false
    
    init(
        transport: TransportHost = TransportHost()
    ) {
        self.transport = transport

        transport.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.connectionState = state
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

    func makeSceneEntity() -> Entity {
        let entity = ModelEntity(
            mesh: .generateBox(size: 0.18),
            materials: [SimpleMaterial(color: .blue, isMetallic: false)]
        )
        entity.position = [0, 0, -0.5]
        controllerEntity = entity
        return entity
    }

    func updateScene() {
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

    private func handle(_ message: NetworkMessage) {
        switch message {
        case let .state(state):
            rodState = state
            connectionState = .streaming
        case .hello, .motion:
            break
        case .discoveryToken:
            break
        }
    }

    private func send(_ message: NetworkMessage) async {
        do {
            try await transport.send(message)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
