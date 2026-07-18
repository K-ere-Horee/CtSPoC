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
    /// Peak angular distance (radians) the pose traveled away from the
    /// calibrated idle pose during this cast gesture's backswing, before
    /// release. Lets `CastResolver` weigh "how far did you pull back"
    /// alongside raw release-moment flick speed, instead of flick speed
    /// alone.
    public let backswingDistance: Float

    public init(
        orientation: RodOrientation,
        angularVelocity: CastVector3,
        timestamp: TimeInterval,
        backswingDistance: Float = 0
    ) {
        self.orientation = orientation
        self.angularVelocity = angularVelocity
        self.timestamp = timestamp
        self.backswingDistance = backswingDistance
    }
}

public struct CastConfig: Codable, Sendable, Equatable {
    public var minimumCastVelocity: Float
    public var maximumCastVelocity: Float
    public var minimumLaunchAngle: Float
    public var maximumLaunchAngle: Float
    /// `backswingDistance` (radians from idle) below which the backswing
    /// contributes no power, and at/above which it contributes full power.
    public var minimumBackswingDistance: Float
    public var maximumBackswingDistance: Float

    public init(
        minimumCastVelocity: Float = 0.8,
        maximumCastVelocity: Float = 5.0,
        minimumLaunchAngle: Float = 0.15,
        maximumLaunchAngle: Float = 0.65,
        minimumBackswingDistance: Float = 0.12,
        maximumBackswingDistance: Float = 1.0
    ) {
        self.minimumCastVelocity = minimumCastVelocity
        self.maximumCastVelocity = maximumCastVelocity
        self.minimumLaunchAngle = minimumLaunchAngle
        self.maximumLaunchAngle = maximumLaunchAngle
        self.minimumBackswingDistance = minimumBackswingDistance
        self.maximumBackswingDistance = maximumBackswingDistance
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

        let distanceSpan = max(config.maximumBackswingDistance - config.minimumBackswingDistance, 0.001)
        let distancePower = min(1, max(0, (snapshot.backswingDistance - config.minimumBackswingDistance) / distanceSpan))

        // How far the backswing traveled sets the base power; a fast release
        // flick only adds up to a 30% bonus on top. You can't cast far with
        // a fast flick alone if you never pulled back for it.
        let normalizedPower = distancePower * (0.7 + 0.3 * flickPower)
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
