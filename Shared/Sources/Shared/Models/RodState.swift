//
//  RodState.swift
//  Shared
//

import Foundation

/// Complete controller snapshot. This is the single source of truth sent to World.
public struct RodState: Codable, Sendable, Equatable {

    public let timestamp: TimeInterval
    public let distance: Float?
    public let directionX: Float?
    public let directionY: Float?
    public let directionZ: Float?
    public let pitch: Double
    public let roll: Double
    public let yaw: Double

    public init(
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        spatial: SpatialState = SpatialState(),
        pitch: Double = 0,
        roll: Double = 0,
        yaw: Double = 0
    ) {
        self.timestamp = timestamp
        distance = spatial.distance
        directionX = spatial.directionX
        directionY = spatial.directionY
        directionZ = spatial.directionZ
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
    }
}
