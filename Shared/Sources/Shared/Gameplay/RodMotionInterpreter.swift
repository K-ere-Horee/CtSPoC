import Foundation

/// Current device motion. Orientation is intentionally kept separate from interpretation.
public struct RodMotionInput: Sendable, Equatable {
    public let timestamp: TimeInterval
    public let pitch: Double
    public let roll: Double
    public let yaw: Double
    public let accelerationZ: Double
    public let rotationRateMagnitude: Double

    public init(
        timestamp: TimeInterval,
        pitch: Double,
        roll: Double,
        yaw: Double,
        rotationRateMagnitude: Double,
        accelerationZ: Double = 0
    ) {
        self.timestamp = timestamp
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.accelerationZ = accelerationZ
        self.rotationRateMagnitude = rotationRateMagnitude
    }
}

public enum RodMotionPhase: String, Sendable, Equatable {
    case invalid
    case idle
    case casting
    case reeling
}

public struct RodMotionInterpretation: Sendable, Equatable {
    public let pose: RodMotionPose
    public let orientation: RodOrientation
    public let isPoseValid: Bool
    public let phase: RodMotionPhase
    public let action: RodAction
    public let reelSpeed: Float
    public let debug: MotionDebugDecision

    public init(
        pose: RodMotionPose,
        orientation: RodOrientation,
        isPoseValid: Bool,
        phase: RodMotionPhase,
        action: RodAction,
        reelSpeed: Float,
        debug: MotionDebugDecision
    ) {
        self.pose = pose
        self.orientation = orientation
        self.isPoseValid = isPoseValid
        self.phase = phase
        self.action = action
        self.reelSpeed = reelSpeed
        self.debug = debug
    }
}

/// Classifies movement by comparing current orientation to the player's poses.
public final class RodMotionInterpreter {
    public var profile: MotionProfile

    private var previousClassification: Classification = .idle
    private var castEndsAt: TimeInterval = 0
    private var hasIdleReference = false

    private enum Classification: String {
        case idle
        case cast
        case reel
    }

    public init(profile: MotionProfile = MotionProfile()) {
        self.profile = profile
    }

    public func updateProfile(_ profile: MotionProfile) {
        self.profile = profile
        previousClassification = .idle
        castEndsAt = 0
        hasIdleReference = profile.isComplete
    }

    /// Installs the idle frame immediately so calibration preview and runtime
    /// rendering consume the same corrected orientation.
    public func setIdlePose(_ pose: MotionPose) {
        profile.idlePose = pose
        profile.calibrationReference = RodOrientation.from(pitch: pose.pitch, roll: pose.roll, yaw: pose.yaw)
        hasIdleReference = true
        previousClassification = .idle
        castEndsAt = 0
    }

    public func interpret(_ input: RodMotionInput) -> RodMotionInterpretation {
        let current = MotionPose(pitch: input.pitch, roll: input.roll, yaw: input.yaw)
        let currentOrientation = RodOrientation.from(pitch: input.pitch, roll: input.roll, yaw: input.yaw)
        
        // debug
        print("CURRENT:", currentOrientation)
        print("CORRECTED:", correctedOrientation(currentOrientation))
        
        guard hasIdleReference else {
            return result(pose: current, orientation: currentOrientation, phase: .invalid, action: .idle, reelSpeed: 0, debug: emptyDebug)
        }

        guard profile.isComplete else {
            return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: .invalid, action: .idle, reelSpeed: 0, debug: emptyDebug)
        }

        let distances = distances(from: current)
        let classification = distances.minimum
        let debug = MotionDebugDecision(
            pitchDelta: distances.idle,
            requiredPitchDelta: distances.cast,
            forwardAcceleration: input.accelerationZ,
            requiredForwardAcceleration: profile.castAcceleration,
            cooldownRemaining: max(0, castEndsAt - input.timestamp),
            passedPitchCheck: classification == .cast,
            passedForwardCheck: input.accelerationZ * profile.castAccelerationSign >= profile.castAcceleration,
            passedCooldownCheck: input.timestamp >= castEndsAt,
            idleDistance: distances.idle,
            castDistance: distances.cast,
            reelDistance: distances.reel,
            selectedPose: classification.rawValue
        )

        if input.timestamp < castEndsAt {
            return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: .casting, action: .casting, reelSpeed: 0, debug: debug)
        }

        switch classification {
        case .cast:
            let forwardMotion = input.accelerationZ * profile.castAccelerationSign >= profile.castAcceleration
            let enteredCast = previousClassification != .cast
            previousClassification = classification
            if forwardMotion && enteredCast {
                castEndsAt = input.timestamp + profile.castDuration
                return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: .casting, action: .casting, reelSpeed: 0, debug: debug)
            }
        case .reel:
            previousClassification = classification
            guard input.rotationRateMagnitude >= profile.reelRotationRate else { break }
            let speed = Float(min(1, input.rotationRateMagnitude / max(profile.reelRotationRate, 1)))
            return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: .reeling, action: .reeling, reelSpeed: speed, debug: debug)
        case .idle:
            previousClassification = classification
        }

        return result(
            pose: relativePose(from: current),
            orientation: correctedOrientation(currentOrientation),
            phase: classification == .idle ? .idle : .invalid,
            action: .idle,
            reelSpeed: 0,
            debug: debug
        )
    }

    private var emptyDebug: MotionDebugDecision {
        MotionDebugDecision(
            pitchDelta: 0,
            requiredPitchDelta: 0,
            forwardAcceleration: 0,
            requiredForwardAcceleration: 0,
            cooldownRemaining: 0,
            passedPitchCheck: false,
            passedForwardCheck: false,
            passedCooldownCheck: false
        )
    }

    private func distances(from current: MotionPose) -> (idle: Double, cast: Double, reel: Double, minimum: Classification) {
        let idle = distance(current, profile.idlePose)
        let cast = distance(current, profile.castPose)
        let reel = distance(current, profile.reelPose)
        if idle <= cast && idle <= reel { return (idle, cast, reel, .idle) }
        if cast <= reel { return (idle, cast, reel, .cast) }
        return (idle, cast, reel, .reel)
    }

    private func distance(_ lhs: MotionPose, _ rhs: MotionPose) -> Double {
        let pitch = wrapped(lhs.pitch - rhs.pitch)
        let roll = wrapped(lhs.roll - rhs.roll)
        let yaw = wrapped(lhs.yaw - rhs.yaw)
        return sqrt((pitch * pitch) + (roll * roll) + (yaw * yaw))
    }

    private func relativePose(from current: MotionPose) -> MotionPose {
        MotionPose(
            pitch: wrapped(current.pitch - profile.idlePose.pitch),
            roll: wrapped(current.roll - profile.idlePose.roll),
            yaw: wrapped(current.yaw - profile.idlePose.yaw)
        )
    }

    private func correctedOrientation(_ current: RodOrientation) -> RodOrientation {
        profile.calibrationReference.inverted() * current
    }

    private func wrapped(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: .pi * 2)
        if value > .pi { value -= .pi * 2 }
        if value < -.pi { value += .pi * 2 }
        return value
    }

    private func result(
        pose: MotionPose,
        orientation: RodOrientation,
        phase: RodMotionPhase,
        action: RodAction,
        reelSpeed: Float,
        debug: MotionDebugDecision
    ) -> RodMotionInterpretation {
        RodMotionInterpretation(pose: pose, orientation: orientation, isPoseValid: profile.isComplete, phase: phase, action: action, reelSpeed: reelSpeed, debug: debug)
    }
}
