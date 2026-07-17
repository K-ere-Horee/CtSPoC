//
//  RodState.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
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
    public let orientation: RodOrientation
    public let action: RodAction
    public let reelSpeed: Float
    public let castSolution: CastSolution?

    public init(
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        spatial: SpatialState = SpatialState(),
        pitch: Double = 0,
        roll: Double = 0,
        yaw: Double = 0,
        orientation: RodOrientation = .identity,
        action: RodAction = .idle,
        reelSpeed: Float = 0
        , castSolution: CastSolution? = nil
    ) {
        self.timestamp = timestamp
        distance = castSolution?.distance ?? spatial.distance
        directionX = castSolution?.direction.x ?? spatial.directionX
        directionY = castSolution?.direction.y ?? spatial.directionY
        directionZ = castSolution?.direction.z ?? spatial.directionZ
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.orientation = orientation
        self.action = action
        self.reelSpeed = reelSpeed
        self.castSolution = castSolution
    }
}
