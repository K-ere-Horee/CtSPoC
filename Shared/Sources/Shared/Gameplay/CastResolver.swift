//
//  CastResolver.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 17/07/26.
//

import Foundation

public struct CastVector3: Codable, Sendable, Equatable {
    public let x: Float
    public let y: Float
    public let z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let forward = CastVector3(x: 0, y: 0, z: -1)

    public var length: Float { sqrt((x * x) + (y * y) + (z * z)) }

    public func normalized() -> CastVector3 {
        let magnitude = length
        guard magnitude > 0 else { return .forward }
        return CastVector3(x: x / magnitude, y: y / magnitude, z: z / magnitude)
    }
}

public struct CastSnapshot: Codable, Sendable, Equatable {
    public let orientation: RodOrientation
    public let angularVelocity: CastVector3
    public let timestamp: TimeInterval
    /// Seconds the pose was held in the backswing/charging zone (since "Start Casting" armed and
    /// the pose first classified as a cast attempt) before this release. Lets `CastResolver` weigh
    /// "how long did you hold it back" alongside raw release-moment flick speed, instead of flick
    /// speed alone — a deliberate "hold to charge" timer, replacing the earlier pull-back-distance
    /// measurement (ADR-032) with something more legible on the cast meter.
    public let backswingHoldDuration: TimeInterval

    public init(
        orientation: RodOrientation,
        angularVelocity: CastVector3,
        timestamp: TimeInterval,
        backswingHoldDuration: TimeInterval = 0
    ) {
        self.orientation = orientation
        self.angularVelocity = angularVelocity
        self.timestamp = timestamp
        self.backswingHoldDuration = backswingHoldDuration
    }
}

public struct CastConfig: Codable, Sendable, Equatable {
    public var minimumCastVelocity: Float
    public var maximumCastVelocity: Float
    public var minimumLaunchAngle: Float
    public var maximumLaunchAngle: Float
    /// `backswingHoldDuration` (seconds) below which holding the backswing contributes no power,
    /// and at/above which it contributes full power.
    public var minimumBackswingHoldDuration: TimeInterval
    public var maximumBackswingHoldDuration: TimeInterval

    public init(
        minimumCastVelocity: Float = 0.8,
        maximumCastVelocity: Float = 5.0,
        minimumLaunchAngle: Float = 0.15,
        maximumLaunchAngle: Float = 0.65,
        minimumBackswingHoldDuration: TimeInterval = 0.15,
        maximumBackswingHoldDuration: TimeInterval = 1.5
    ) {
        self.minimumCastVelocity = minimumCastVelocity
        self.maximumCastVelocity = maximumCastVelocity
        self.minimumLaunchAngle = minimumLaunchAngle
        self.maximumLaunchAngle = maximumLaunchAngle
        self.minimumBackswingHoldDuration = minimumBackswingHoldDuration
        self.maximumBackswingHoldDuration = maximumBackswingHoldDuration
    }
}

public struct CastSolution: Codable, Sendable, Equatable {
    public let direction: CastVector3
    public let power: Float
    public let launchAngle: Float
    public let distance: Float

    public init(direction: CastVector3, power: Float, launchAngle: Float, distance: Float = 0) {
        self.direction = direction
        self.power = power
        self.launchAngle = launchAngle
        self.distance = distance
    }

    public func with(distance: Float) -> CastSolution {
        CastSolution(direction: direction, power: power, launchAngle: launchAngle, distance: distance)
    }
}

public struct CastMeterConfig: Codable, Sendable, Equatable {
    public var shortMaximum: Float
    public var mediumMaximum: Float
    public var longMaximum: Float

    public init(shortMaximum: Float = 6, mediumMaximum: Float = 12, longMaximum: Float = 18) {
        self.shortMaximum = shortMaximum
        self.mediumMaximum = mediumMaximum
        self.longMaximum = longMaximum
    }

    public func distance(for power: Float) -> Float {
        let normalized = min(1, max(0, power))
        if normalized < 0.33 { return shortMaximum * (normalized / 0.33) }
        if normalized < 0.66 {
            return shortMaximum + ((mediumMaximum - shortMaximum) * ((normalized - 0.33) / 0.33))
        }
        return mediumMaximum + ((longMaximum - mediumMaximum) * ((normalized - 0.66) / 0.34))
    }
}

/// Converts an immutable motion snapshot into gameplay-ready cast values.
public struct CastResolver: Sendable {
    public let config: CastConfig

    public init(config: CastConfig = CastConfig()) {
        self.config = config
    }

    public func resolve(_ snapshot: CastSnapshot) -> CastSolution {
        let forward = snapshot.orientation.act(.forward)
        var horizontal = CastVector3(x: forward.x, y: 0, z: forward.z).normalized()
        if horizontal.length == 0 { horizontal = .forward }

        let velocitySpan = max(config.maximumCastVelocity - config.minimumCastVelocity, 0.001)
        let flickPower = min(1, max(0, (snapshot.angularVelocity.length - config.minimumCastVelocity) / velocitySpan))

        let holdSpan = max(config.maximumBackswingHoldDuration - config.minimumBackswingHoldDuration, 0.001)
        let holdPower = Float(min(1, max(0, (snapshot.backswingHoldDuration - config.minimumBackswingHoldDuration) / holdSpan)))

        // How long the backswing was held sets the base power; a fast release
        // flick only adds up to a 30% bonus on top. You can't cast far with
        // a fast flick alone if you never held the charge for it.
        let normalizedPower = holdPower * (0.7 + 0.3 * flickPower)
        let launchAngle = config.minimumLaunchAngle
            + ((config.maximumLaunchAngle - config.minimumLaunchAngle) * normalizedPower)

        return CastSolution(direction: horizontal, power: normalizedPower, launchAngle: launchAngle)
    }
}

public extension RodOrientation {
    func act(_ vector: CastVector3) -> CastVector3 {
        let qVector = CastVector3(x: Float(x), y: Float(y), z: Float(z))
        let uv = cross(qVector, vector)
        let uuv = cross(qVector, uv)
        let scale = Float(2 * w)
        return CastVector3(
            x: vector.x + (scale * uv.x) + (2 * uuv.x),
            y: vector.y + (scale * uv.y) + (2 * uuv.y),
            z: vector.z + (scale * uv.z) + (2 * uuv.z)
        )
    }
}

private func cross(_ lhs: CastVector3, _ rhs: CastVector3) -> CastVector3 {
    CastVector3(
        x: lhs.y * rhs.z - lhs.z * rhs.y,
        y: lhs.z * rhs.x - lhs.x * rhs.z,
        z: lhs.x * rhs.y - lhs.y * rhs.x
    )
}
