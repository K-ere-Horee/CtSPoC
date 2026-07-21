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
    /// Gates cast/reel gesture reporting. The player must explicitly
    /// "Start Fishing" (after calibrating) before physical motion is
    /// interpreted as gameplay intent; "End Fishing" clears it again.
    @Published private(set) var isFishing = false
    /// Gates whether `RodMotionInterpreter` treats a cast-classified pose as a real cast attempt.
    /// Set by the "Start Casting" button, not automatic — otherwise ordinary phone movement that
    /// happens to read closest to the calibrated `castPose` would silently start charging. Cleared
    /// automatically once a cast actually fires (`updateAction()`), whenever `hookPhase` leaves
    /// `.idle`, or on `endFishing()` — a stale arm can never survive past one cast attempt.
    @Published private(set) var isCastingArmed = false

    /// Debug-only: the calibrated `reelSpeed` ramp's min/max rotation rate (`calibrateMotion()`'s
    /// `.reel` step), surfaced so a narrow calibrated range — the leading suspect for the
    /// "reel speed feels constant" report, see `CHECKPOINT.md`'s ADR-042 follow-up TODO — can be
    /// confirmed or ruled out from a live device during the next playtest instead of guessed at.
    var reelCalibrationRange: (min: Double, max: Double) {
        (motionInterpreter.profile.reelRotationRate, motionInterpreter.profile.reelFullRotationRate)
    }

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
    )
    private var pose = RodMotionPose(pitch: 0, roll: 2, yaw: 0)
    private var orientation = RodOrientation.identity
    private var spatial = SpatialState()
    private var hasStarted = false
    private var calibrationSamples: [RodMotionInput] = []
    /// Guards against unbounded concurrent sends: `publishState()` fires on every motion sample
    /// (up to the CoreMotion update rate), and each one used to spawn its own unstructured `Task`
    /// with no backpressure — if a send was momentarily slow, tasks piled up and could finish out
    /// of step with real time, reading as input lag. Since only the newest state ever matters,
    /// drop a publish rather than queue it while a send is already in flight.
    private var isSendingState = false

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
                #if DEBUG
                print("Rod onUpdate")
                #endif
                self?.updateAction()
                #if DEBUG
                print("Entered updateAction")
                #endif
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
                if state == .ready {
                    self?.lastError = nil
                    self?.startSpatialSession()
                }
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
        motionManager.start()
        #if DEBUG
        print("Motion Update, sample count: \(debugRecorder.sampleCount)")
        #endif
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

    /// The World this session is paired with (see `PairedCentralStore`), for display in Developer
    /// Details — `nil` until a central has ever subscribed. `CBCentral` has no display name, only
    /// an identifier, so only a short ID is shown.
    var pairedDeviceShortID: String? { transport.pairedDeviceShortID }
    var hasPairedDevice: Bool { transport.hasPairedDevice }

    /// Clears the saved pairing so the next Mac to subscribe becomes the new paired device.
    func forgetPairedDevice() {
        transport.forgetPairedDevice()
    }

    func startFishing() {
        guard calibrationStep == .complete else { return }
        isFishing = true
    }

    func endFishing() {
        isFishing = false
        isCastingArmed = false
    }

    /// Arms one cast attempt: until this is pressed, `RodMotionInterpreter` ignores a
    /// cast-classified pose entirely (see its own doc comment), so idly holding or moving the
    /// phone can never accidentally start charging a cast. Requires an actual fishing session and
    /// an idle hook — mirrors `HookPhase.allowsCasting`, since arming while a cast couldn't
    /// possibly be allowed to complete would just leave the button stuck "armed" for nothing.
    func startCasting() {
        guard isFishing, hookPhase == .idle, !isCastingArmed else { return }
        isCastingArmed = true
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
            let peakRate = rates.max() ?? averageRate
            motionInterpreter.profile.reelRotationRate = max(0.2, averageRate * 0.45)
            motionInterpreter.profile.reelFullRotationRate = max(
                motionInterpreter.profile.reelRotationRate + 0.3,
                peakRate
            )
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
            if phase != .idle {
                isCastingArmed = false
            }
            if phase != .hookInWater {
                fishingHaptics.stopInterest()
            }
            if phase != .fishOnHook, phase != .reeling {
                fishingHaptics.stopFight()
            }
            if phase == .idle {
                rodState = RodState(
                    spatial: spatial,
                    pitch: pose.pitch,
                    roll: pose.roll,
                    yaw: pose.yaw,
                    orientation: orientation,
                    action: action,
                    reelSpeed: reelSpeed,
                    castSolution: nil,
                    isFishing: isFishing
                )
                publishState()
            }
        case .state:
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
            reelSpeed: reelSpeed,
            castSolution: rodState.castSolution,
            motionPhase: rodState.motionPhase,
            castPower: rodState.castPower,
            castHoldDuration: rodState.castHoldDuration,
            isFishing: isFishing
        )
        guard connectionState == .ready || connectionState == .streaming else { return }
        connectionState = .streaming

        guard !isSendingState else { return }
        isSendingState = true
        let stateToSend = rodState
        Task {
            await send(.state(stateToSend))
            isSendingState = false
        }
    }

    private func updateAction() {
        let previousAction = action
        motionAccelerationZ = motion.accelerationZ
        motionRotationRate = motion.rotationRateMagnitude
        let interpretation = motionInterpreter.interpret(motionInput, isCastingArmed: isCastingArmed)
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
            // A real cast just fired — one "Start Casting" press only ever arms a single attempt.
            isCastingArmed = false
        } else {
            resolvedCastSolution = rodState.castSolution
        }
        
        action = !isFishing
            ? .idle
            : interpretation.action == .casting && !hookPhase.allowsCasting
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
            castSolution: resolvedCastSolution,
            motionPhase: motionPhase,
            castPower: interpretation.castPower,
            castHoldDuration: interpretation.castHoldDuration,
            isFishing: isFishing
        )

        if action == .casting, previousAction != .casting {
            fishingHaptics.handle(.cast)
        }
        if action == .reeling {
            fishingHaptics.reelTick(reelSpeed: reelSpeed)
        }
        fishingHaptics.interestPulse()
        fishingHaptics.fightPulse()
    }

    private var motionInput: RodMotionInput {
        RodMotionInput(
            timestamp: motion.timestamp,
            pitch: motion.pitch,
            roll: motion.roll,
            yaw: motion.yaw,
            rotationRateMagnitude: motion.rotationRateMagnitude,
            accelerationZ: motion.accelerationZ
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
            lastError = nil
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
