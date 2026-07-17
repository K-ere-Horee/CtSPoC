import Foundation

/// A pure orientation captured from CoreMotion.
public struct MotionPose: Codable, Sendable, Equatable {
    public let pitch: Double
    public let roll: Double
    public let yaw: Double

    public init(pitch: Double, roll: Double, yaw: Double) {
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
    }
}

/// Backward-compatible name for existing Rod state and UI code.
public typealias RodMotionPose = MotionPose

public struct MotionProfile: Codable, Sendable, Equatable {
    public var isComplete: Bool
    public var idlePose: MotionPose
    public var castPose: MotionPose
    public var reelPose: MotionPose
    public var castAcceleration: Double
    public var castAccelerationSign: Double
    public var reelRotationRate: Double
    public var castDuration: TimeInterval

    public init(
        isComplete: Bool = false,
        idlePose: MotionPose = MotionPose(pitch: 0, roll: 0, yaw: 0),
        castPose: MotionPose = MotionPose(pitch: 0, roll: 0, yaw: 0),
        reelPose: MotionPose = MotionPose(pitch: 0, roll: 0, yaw: 0),
        castAcceleration: Double = 0,
        castAccelerationSign: Double = 1,
        reelRotationRate: Double = 0,
        castDuration: TimeInterval = 0.25
    ) {
        self.isComplete = isComplete
        self.idlePose = idlePose
        self.castPose = castPose
        self.reelPose = reelPose
        self.castAcceleration = castAcceleration
        self.castAccelerationSign = castAccelerationSign
        self.reelRotationRate = reelRotationRate
        self.castDuration = castDuration
    }
}
