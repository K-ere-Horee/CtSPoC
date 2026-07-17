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
    @Published private(set) var hasMotionSample = false
    @Published private(set) var action: RodAction = .idle
    @Published private(set) var reelSpeed: Float = 0
    @Published private(set) var motionPhase: RodMotionPhase = .invalid
    @Published private(set) var isPoseValid = false
    @Published private(set) var motionAccelerationZ: Double = 0
    @Published private(set) var motionRotationRate: Double = 0
    @Published private(set) var lastError: String?

    private let motionManager: MotionManager
    private let motionInterpreter: RodMotionInterpreter
    private let spatialManager: NearbyInteractionManager
    private let transport: TransportClient
    private let fishingHaptics: FishingHaptics

    private var motion = MotionSample(
        timestamp: 0,
        pitch: 0,
        roll: 0,
        yaw: 0,
        accelerationZ: 0,
        rotationRateMagnitude: 0
    )
    private var pose = RodMotionPose(pitch: 0, roll: 2, yaw: 0)
    private var spatial = SpatialState()
    private var hasStarted = false

    init(
        motionManager: MotionManager = MotionManager(),
        motionInterpreter: RodMotionInterpreter = RodMotionInterpreter(),
        spatialManager: NearbyInteractionManager = NearbyInteractionManager(),
        transport: TransportClient = TransportClient(),
        fishingHaptics: FishingHaptics = FishingHaptics()
    ) {
        self.motionManager = motionManager
        self.motionInterpreter = motionInterpreter
        self.spatialManager = spatialManager
        self.transport = transport
        self.fishingHaptics = fishingHaptics
        motionAvailable = motionManager.isAvailable

        motionManager.onUpdate = { [weak self] sample in
            Task { @MainActor in
                self?.motion = sample
                self?.hasMotionSample = true
                self?.updateAction()
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

    func calibrateMotion() {
        guard hasMotionSample else { return }
        motionInterpreter.calibrate(to: motionInput)
        updateAction()
        publishState()
    }

    private func startSpatialSession() {
        spatialManager.start()
    }

    private func handle(_ message: NetworkMessage) {
        switch message {
        case let .discoveryToken(data):
            spatialManager.handleDiscoveryToken(data)
        case let .fishingEvent(event):
            fishingHaptics.handle(event)
        case .hello, .motion, .state:
            break
        }
    }

    private func publishState() {
        rodState = RodState(
            spatial: spatial,
            pitch: pose.pitch,
            roll: pose.roll,
            yaw: pose.yaw,
            action: action,
            reelSpeed: reelSpeed
        )
        guard connectionState == .ready || connectionState == .streaming else { return }
        connectionState = .streaming
        Task { await send(.state(rodState)) }
    }

    private func updateAction() {
        let previousAction = action
        motionAccelerationZ = motion.accelerationZ
        motionRotationRate = motion.rotationRateMagnitude
        let interpretation = motionInterpreter.interpret(motionInput)
        pose = interpretation.pose
        action = interpretation.action
        reelSpeed = interpretation.reelSpeed
        motionPhase = interpretation.phase
        isPoseValid = interpretation.isPoseValid

        if action == .casting, previousAction != .casting {
            fishingHaptics.handle(.cast)
        }
        if action == .reeling {
            fishingHaptics.reelTick(reelSpeed: reelSpeed)
        }
    }

    private var motionInput: RodMotionInput {
        RodMotionInput(
            timestamp: motion.timestamp,
            pitch: motion.pitch,
            roll: motion.roll,
            yaw: motion.yaw,
            rotationRateMagnitude: motion.rotationRateMagnitude
        )
    }

    private func send(_ message: NetworkMessage) async {
        do {
            try await transport.send(message)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
