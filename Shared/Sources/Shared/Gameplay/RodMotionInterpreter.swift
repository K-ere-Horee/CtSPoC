import Foundation

/// Raw device-motion values supplied by the controller application.
public struct RodMotionInput: Sendable, Equatable {
    public let timestamp: TimeInterval
    public let pitch: Double
    public let roll: Double
    public let yaw: Double
    public let rotationRateMagnitude: Double

    public init(
        timestamp: TimeInterval,
        pitch: Double,
        roll: Double,
        yaw: Double,
        rotationRateMagnitude: Double
    ) {
        self.timestamp = timestamp
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.rotationRateMagnitude = rotationRateMagnitude
    }
}

/// A constrained virtual rod pose, expressed in radians.
public struct RodMotionPose: Sendable, Equatable {
    public let pitch: Double
    public let roll: Double
    public let yaw: Double

    public init(pitch: Double, roll: Double, yaw: Double) {
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
    }
}

public enum RodMotionPhase: String, Sendable, Equatable {
    case invalid
    case ready
    case casting
    case waiting
    case reeling
}

public struct RodMotionInterpretation: Sendable, Equatable {
    public let pose: RodMotionPose
    public let isPoseValid: Bool
    public let phase: RodMotionPhase
    public let action: RodAction
    public let reelSpeed: Float
}

/// Converts unrestricted device orientation into constrained rod intent.
public final class RodMotionInterpreter {

    public static let pitchRange = -0.3...1.0
    public static let rollRange = 1.0...3.0
    public static let yawRange = -2.5...2.5

    private let castPitchDeltaThreshold = 0.12
    private let reelRotationThreshold = 1.4
    private let castDuration: TimeInterval = 0.25
    private let castCooldown: TimeInterval = 0.5
    private let smoothingFactor = 0.18
    private let neutralRoll = 2.0

    private var homeOrientation: RodMotionInput?
    private var smoothedPose: RodMotionPose?
    private var previousPitch: Double?
    private var castEndsAt: TimeInterval = 0
    private var nextCastAllowedAt: TimeInterval = 0

    public init() {}

    /// Uses the supplied device attitude as the new controller home pose.
    public func calibrate(to input: RodMotionInput) {
        homeOrientation = input
        let pose = rawPose(from: input)
        smoothedPose = pose
        previousPitch = pose.pitch
        castEndsAt = 0
        nextCastAllowedAt = 0
    }

    public func interpret(_ input: RodMotionInput) -> RodMotionInterpretation {
        if homeOrientation == nil {
            calibrate(to: input)
        }

        let targetPose = rawPose(from: input)
        let isPoseValid = isValid(targetPose)
        let constrainedPose = constrained(targetPose)
        let pose = smoothed(constrainedPose)
        let previousPitch = previousPitch
        self.previousPitch = targetPose.pitch

        guard isPoseValid else {
            return interpretation(
                pose: pose,
                isPoseValid: false,
                phase: .invalid,
                action: .idle,
                reelSpeed: 0
            )
        }

        if input.timestamp < castEndsAt {
            return interpretation(
                pose: pose,
                isPoseValid: true,
                phase: .casting,
                action: .casting,
                reelSpeed: 0
            )
        }

        let pitchDelta = targetPose.pitch - (previousPitch ?? targetPose.pitch)
        if pitchDelta >= castPitchDeltaThreshold, input.timestamp >= nextCastAllowedAt {
            castEndsAt = input.timestamp + castDuration
            nextCastAllowedAt = input.timestamp + castCooldown
            return interpretation(
                pose: pose,
                isPoseValid: true,
                phase: .casting,
                action: .casting,
                reelSpeed: 0
            )
        }

        if input.timestamp < nextCastAllowedAt {
            return interpretation(
                pose: pose,
                isPoseValid: true,
                phase: .waiting,
                action: .idle,
                reelSpeed: 0
            )
        }

        guard input.rotationRateMagnitude > reelRotationThreshold else {
            return interpretation(
                pose: pose,
                isPoseValid: true,
                phase: .ready,
                action: .idle,
                reelSpeed: 0
            )
        }

        let reelSpeed = Float(min(1, input.rotationRateMagnitude / 7))
        return interpretation(
            pose: pose,
            isPoseValid: true,
            phase: .reeling,
            action: .reeling,
            reelSpeed: reelSpeed
        )
    }

    private func rawPose(from input: RodMotionInput) -> RodMotionPose {
        guard let homeOrientation else {
            return RodMotionPose(pitch: 0, roll: neutralRoll, yaw: 0)
        }

        return RodMotionPose(
            pitch: wrappedAngle(input.pitch - homeOrientation.pitch),
            roll: neutralRoll + wrappedAngle(input.roll - homeOrientation.roll),
            yaw: wrappedAngle(input.yaw - homeOrientation.yaw)
        )
    }

    private func isValid(_ pose: RodMotionPose) -> Bool {
        Self.pitchRange.contains(pose.pitch)
            && Self.rollRange.contains(pose.roll)
            && Self.yawRange.contains(pose.yaw)
    }

    private func constrained(_ pose: RodMotionPose) -> RodMotionPose {
        RodMotionPose(
            pitch: min(max(pose.pitch, Self.pitchRange.lowerBound), Self.pitchRange.upperBound),
            roll: min(max(pose.roll, Self.rollRange.lowerBound), Self.rollRange.upperBound),
            yaw: min(max(pose.yaw, Self.yawRange.lowerBound), Self.yawRange.upperBound)
        )
    }

    private func smoothed(_ target: RodMotionPose) -> RodMotionPose {
        guard let smoothedPose else {
            self.smoothedPose = target
            return target
        }

        let pose = RodMotionPose(
            pitch: interpolate(smoothedPose.pitch, target.pitch),
            roll: interpolate(smoothedPose.roll, target.roll),
            yaw: interpolate(smoothedPose.yaw, target.yaw)
        )
        self.smoothedPose = pose
        return pose
    }

    private func interpolate(_ current: Double, _ target: Double) -> Double {
        current + ((target - current) * smoothingFactor)
    }

    private func wrappedAngle(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: .pi * 2)
        if value > .pi {
            value -= .pi * 2
        } else if value < -.pi {
            value += .pi * 2
        }
        return value
    }

    private func interpretation(
        pose: RodMotionPose,
        isPoseValid: Bool,
        phase: RodMotionPhase,
        action: RodAction,
        reelSpeed: Float
    ) -> RodMotionInterpretation {
        RodMotionInterpretation(
            pose: pose,
            isPoseValid: isPoseValid,
            phase: phase,
            action: action,
            reelSpeed: reelSpeed
        )
    }
}
