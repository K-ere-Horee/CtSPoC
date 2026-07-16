//
//  RodViewModel.swift
//  Rod
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import SwiftUI
import Shared
import Combine

@MainActor
final class RodViewModel: ObservableObject {

    @Published private(set) var rodState = RodState()
    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var spatialStatus: SpatialStatus = .unavailable
    @Published private(set) var motionAvailable = false
    @Published private(set) var lastError: String?

    private let motionManager: MotionManager
    private let spatialManager: NearbyInteractionManager
    private let transport: TransportClient

    private var motion = MotionSample(pitch: 0, roll: 0, yaw: 0)
    private var spatial = SpatialState()
    private var hasStarted = false

    init(
        motionManager: MotionManager = MotionManager(),
        spatialManager: NearbyInteractionManager = NearbyInteractionManager(),
        transport: TransportClient = TransportClient()
    ) {
        self.motionManager = motionManager
        self.spatialManager = spatialManager
        self.transport = transport
        motionAvailable = motionManager.isAvailable

        motionManager.onUpdate = { [weak self] sample in
            Task { @MainActor in
                self?.motion = sample
                self?.publishState()
            }
        }
        spatialManager.onSpatialUpdate = { [weak self] state in
            Task { @MainActor in
                self?.spatial = state
                self?.publishState()
            }
        }
        spatialManager.onStatusChange = { [weak self] status in
            Task { @MainActor in self?.spatialStatus = status }
        }
        spatialManager.onDiscoveryToken = { [weak self] data in
            Task { @MainActor in await self?.send(.discoveryToken(data)) }
        }
        transport.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.connectionState = state
                if state == .ready { self?.startSpatialSession() }
            }
        }
        transport.onMessage = { [weak self] message in
            Task { @MainActor in self?.handle(message) }
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        motionManager.start()
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
        motionManager.stop()
        transport.disconnect()
        hasStarted = false
    }

    private func startSpatialSession() {
        spatialManager.start()
    }

    private func handle(_ message: NetworkMessage) {
        if case let .discoveryToken(data) = message {
            spatialManager.handleDiscoveryToken(data)
        }
    }

    private func publishState() {
        rodState = RodState(
            spatial: spatial,
            pitch: motion.pitch,
            roll: motion.roll,
            yaw: motion.yaw
        )
        guard connectionState == .ready || connectionState == .streaming else { return }
        connectionState = .streaming
        Task { await send(.state(rodState)) }
    }

    private func send(_ message: NetworkMessage) async {
        do {
            try await transport.send(message)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
