//
//  MotionProfile.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 15/07/26.
//

import Foundation

public struct RodOrientation: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let z: Double
    public let w: Double

    public static let identity = RodOrientation(x: 0, y: 0, z: 0, w: 1)

    public init(x: Double, y: Double, z: Double, w: Double) {
        let length = sqrt((x * x) + (y * y) + (z * z) + (w * w))
        guard length > 0 else {
            self = .identity
            return
        }
        self.x = x / length
        self.y = y / length
        self.z = z / length
        self.w = w / length
    }

    public func inverted() -> RodOrientation {
        RodOrientation(x: -x, y: -y, z: -z, w: w)
    }

    public static func * (lhs: RodOrientation, rhs: RodOrientation) -> RodOrientation {
        RodOrientation(
            x: lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
            z: lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w,
            w: lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z
        )
    }

    public static func from(pitch: Double, roll: Double, yaw: Double) -> RodOrientation {
        let pitchHalf = pitch * 0.5
        let rollHalf = roll * 0.5
        let yawHalf = yaw * 0.5
        let pitchQ = RodOrientation(x: sin(pitchHalf), y: 0, z: 0, w: cos(pitchHalf))
        let rollQ = RodOrientation(x: 0, y: 0, z: sin(rollHalf), w: cos(rollHalf))
        let yawQ = RodOrientation(x: 0, y: sin(yawHalf), z: 0, w: cos(yawHalf))
        return yawQ * pitchQ * rollQ
    }
}

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
    public var calibrationReference: RodOrientation
    public var castPose: MotionPose
    public var reelPose: MotionPose
    public var castAcceleration: Double
    public var castAccelerationSign: Double
    public var reelRotationRate: Double
    public var reelFullRotationRate: Double
    public var castDuration: TimeInterval

    public init(
        isComplete: Bool = false,
        idlePose: MotionPose = MotionPose(pitch: 0, roll: 0, yaw: 0),
        calibrationReference: RodOrientation = .identity,
        castPose: MotionPose = MotionPose(pitch: 0, roll: 0, yaw: 0),
        reelPose: MotionPose = MotionPose(pitch: 0, roll: 0, yaw: 0),
        castAcceleration: Double = 0,
        castAccelerationSign: Double = 1,
        reelRotationRate: Double = 0,
        reelFullRotationRate: Double = 0,
        castDuration: TimeInterval = 0.25
    ) {
        self.isComplete = isComplete
        self.idlePose = idlePose
        self.calibrationReference = calibrationReference
        self.castPose = castPose
        self.reelPose = reelPose
        self.castAcceleration = castAcceleration
        self.castAccelerationSign = castAccelerationSign
        self.reelRotationRate = reelRotationRate
        self.reelFullRotationRate = reelFullRotationRate
        self.castDuration = castDuration
    }
}
