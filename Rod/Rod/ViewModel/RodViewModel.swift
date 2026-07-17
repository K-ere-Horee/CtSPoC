//
//  RodViewModel.swift
//  Rod
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import SwiftUI
import Shared
import Combine

enum MotionCalibrationStep: String {
    case idle
    case cast
    case reel
    case complete
}

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
    @Published private(set) var hookPhase: HookPhase = .idle
    @Published private(set) var motionAccelerationZ: Double = 0
    @Published private(set) var motionRotationRate: Double = 0
    @Published private(set) var lastError: String?
    @Published private(set) var calibrationStep: MotionCalibrationStep = .idle
    @Published private(set) var calibrationSampleCount = 0

    private let motionManager: MotionManager
    private let motionInterpreter: RodMotionInterpreter
    private let spatialManager: NearbyInteractionManager
    private let transport: TransportClient
    private let fishingHaptics: FishingHaptics
    private let castResolver = CastResolver()
    private let castMeterConfig = CastMeterConfig()

    private var motion = MotionSample(
        timestamp: 0,
        pitch: 0,
        roll: 0,
            yaw: 0,
            accelerationZ: 0,
        rotationRateMagnitude: 0
        , rotationRateX: 0
        , rotationRateY: 0
        , rotationRateZ: 0
    )
    private var pose = RodMotionPose(pitch: 0, roll: 2, yaw: 0)
    private var orientation = RodOrientation.identity
    private var spatial = SpatialState()
    private var hasStarted = false
    private var calibrationSamples: [RodMotionInput] = []

    private static let motionProfileKey = "rod.motionProfile"

    let debugRecorder = MotionDebugRecorder()

    init(
        motionManager: MotionManager,
        motionInterpreter: RodMotionInterpreter,
        spatialManager: NearbyInteractionManager,
        transport: TransportClient,
        fishingHaptics: FishingHaptics
    ) {
        self.motionManager = motionManager
        if let storedProfile = Self.loadMotionProfile() {
            motionInterpreter.updateProfile(storedProfile)
            calibrationStep = storedProfile.isComplete ? .complete : .idle
        }
        self.motionInterpreter = motionInterpreter
        self.spatialManager = spatialManager
        self.transport = transport
        self.fishingHaptics = fishingHaptics
        motionAvailable = motionManager.isAvailable

        motionManager.onUpdate = { [weak self] sample in
            Task { @MainActor in
                self?.motion = sample
                self?.hasMotionSample = true
                self?.collectCalibrationSample()
                print("Rod onUpdate")
                self?.updateAction()
                print("Entered updateAction")
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
        debugRecorder.start()
        print(debugRecorder.sampleCount)
        motionManager.start()
        print("Motion Update")
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
        switch calibrationStep {
        case .idle:
            guard calibrationSamples.count >= 3 else { return }
            motionInterpreter.setIdlePose(averagePose(of: calibrationSamples))
            motionInterpreter.profile.isComplete = false
            calibrationSamples.removeAll(keepingCapacity: true)
            calibrationSampleCount = 0
            calibrationStep = .cast
        case .cast:
            let samples = calibrationSamples
            guard samples.count >= 3 else { return }
            motionInterpreter.profile.castPose = averagePose(of: Array(samples.suffix(10)))
            let peakAccelerationSample = samples.max { abs($0.accelerationZ) < abs($1.accelerationZ) }
            let peakAcceleration = abs(peakAccelerationSample?.accelerationZ ?? 0.08)
            let duration = max(0.15, (samples.last?.timestamp ?? 0) - (samples.first?.timestamp ?? 0))
            motionInterpreter.profile.castAcceleration = max(0.01, peakAcceleration * 0.2)
            motionInterpreter.profile.castAccelerationSign = (peakAccelerationSample?.accelerationZ ?? 1) >= 0 ? 1 : -1
            motionInterpreter.profile.castDuration = min(0.8, duration)
            calibrationSamples.removeAll(keepingCapacity: true)
            calibrationSampleCount = 0
            calibrationStep = .reel
        case .reel:
            let samples = calibrationSamples
            guard samples.count >= 3 else { return }
            motionInterpreter.profile.reelPose = averagePose(of: samples)
            let rates = samples.map(\.rotationRateMagnitude)
            let averageRate = rates.reduce(0, +) / Double(rates.count)
            motionInterpreter.profile.reelRotationRate = max(0.2, averageRate * 0.45)
            motionInterpreter.profile.isComplete = true
            calibrationSamples.removeAll(keepingCapacity: true)
            calibrationSampleCount = 0
            calibrationStep = .complete
            Self.saveMotionProfile(motionInterpreter.profile)
        case .complete:
            calibrationStep = .idle
            motionInterpreter.profile.isComplete = false
            Self.saveMotionProfile(motionInterpreter.profile)
        }
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
        case let .hookPhase(phase):
            hookPhase = phase
            if phase == .idle {
                rodState = RodState(
                    spatial: spatial,
                    pitch: pose.pitch,
                    roll: pose.roll,
                    yaw: pose.yaw,
                    orientation: orientation,
                    action: action,
                    reelSpeed: reelSpeed,
                    castSolution: nil
                )
                publishState()
            }
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
            orientation: orientation,
            action: action,
            reelSpeed: reelSpeed
            , castSolution: rodState.castSolution
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
        debugRecorder.append(
            MotionDebugSample(
                input: motionInput,
                interpretation: interpretation,
                decision: interpretation.debug
            )
        )
        pose = interpretation.pose
        orientation = interpretation.orientation
        let resolvedCastSolution: CastSolution?
        if let snapshot = interpretation.castSnapshot {
            let resolved = castResolver.resolve(snapshot)
            resolvedCastSolution = resolved.with(distance: castMeterConfig.distance(for: resolved.power))
        } else {
            resolvedCastSolution = rodState.castSolution
        }
        
        action = interpretation.action == .casting && !hookPhase.allowsCasting
            ? .idle
            : interpretation.action == .reeling && !hookPhase.allowsReeling
            ? .idle
            : interpretation.action
        reelSpeed = interpretation.reelSpeed
        motionPhase = interpretation.phase
        isPoseValid = interpretation.isPoseValid
        rodState = RodState(
            spatial: spatial,
            pitch: pose.pitch,
            roll: pose.roll,
            yaw: pose.yaw,
            orientation: orientation,
            action: action,
            reelSpeed: reelSpeed,
            castSolution: resolvedCastSolution
        )

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
            rotationRateMagnitude: motion.rotationRateMagnitude,
            accelerationZ: motion.accelerationZ
            , rotationRateX: motion.rotationRateX
            , rotationRateY: motion.rotationRateY
            , rotationRateZ: motion.rotationRateZ
        )
    }

    private func collectCalibrationSample() {
        guard calibrationStep != .complete else { return }
        calibrationSamples.append(motionInput)
        if calibrationSamples.count > 180 { calibrationSamples.removeFirst() }
        calibrationSampleCount = calibrationSamples.count
    }

    private func averagePose(of samples: [RodMotionInput]) -> MotionPose {
        let count = Double(samples.count)
        return MotionPose(
            pitch: samples.map(\.pitch).reduce(0, +) / count,
            roll: samples.map(\.roll).reduce(0, +) / count,
            yaw: samples.map(\.yaw).reduce(0, +) / count
        )
    }

    private func send(_ message: NetworkMessage) async {
        do {
            try await transport.send(message)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static func loadMotionProfile() -> MotionProfile? {
        guard let data = UserDefaults.standard.data(forKey: motionProfileKey) else { return nil }
        return try? JSONDecoder().decode(MotionProfile.self, from: data)
    }

    private static func saveMotionProfile(_ profile: MotionProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: motionProfileKey)
    }
}
