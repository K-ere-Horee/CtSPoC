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
    public let timestamp: TimeInterval
    /// Seconds the pose was held in the backswing/charging zone (since "Start Casting" armed and
    /// the pose first classified as a cast attempt) before this release — fed through
    /// `CastConfig.oscillationPeriod`'s timing-meter curve (ADR-057) to become power. Not a
    /// monotonic charge: the resulting power rises and falls continuously for as long as the
    /// backswing is held, so releasing at a different instant gives a different power even for the
    /// same total hold time. The flick always triggers the release; it never scales the result
    /// (ADR-056).
    public let backswingHoldDuration: TimeInterval

    public init(
        orientation: RodOrientation,
        timestamp: TimeInterval,
        backswingHoldDuration: TimeInterval = 0
    ) {
        self.orientation = orientation
        self.timestamp = timestamp
        self.backswingHoldDuration = backswingHoldDuration
    }
}

public struct CastConfig: Codable, Sendable, Equatable {
    public var minimumLaunchAngle: Float
    public var maximumLaunchAngle: Float
    /// Seconds for one full oscillation of the timing meter (0 -> 1 -> 0), continuously repeating
    /// for as long as the backswing is held (ADR-057) — "meteran naik turun perlahan," a classic
    /// timing-minigame curve rather than a charge-and-cap ramp. The flick locks in whatever power
    /// the meter reads at that exact instant.
    public var oscillationPeriod: TimeInterval

    public init(
        minimumLaunchAngle: Float = 0.15,
        maximumLaunchAngle: Float = 0.65,
        oscillationPeriod: TimeInterval = 3.5
    ) {
        self.minimumLaunchAngle = minimumLaunchAngle
        self.maximumLaunchAngle = maximumLaunchAngle
        self.oscillationPeriod = oscillationPeriod
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

        // Timing-meter curve (ADR-057): power oscillates continuously between 0 and 1 for as long
        // as the backswing is held, instead of ramping up and capping. `(1 - cos(t)) / 2` starts at
        // 0, peaks at 1 halfway through `oscillationPeriod`, returns to 0 at the full period, and
        // repeats — the flick (never this formula) decides when to lock in whatever it reads.
        let period = max(config.oscillationPeriod, 0.001)
        let phase = snapshot.backswingHoldDuration * 2 * Double.pi / period
        let normalizedPower = Float((1 - cos(phase)) / 2)
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
