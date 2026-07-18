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
    public let motionPhase: RodMotionPhase
    public let castPower: Float

    public init(
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        spatial: SpatialState = SpatialState(),
        pitch: Double = 0,
        roll: Double = 0,
        yaw: Double = 0,
        orientation: RodOrientation = .identity,
        action: RodAction = .idle,
        reelSpeed: Float = 0,
        castSolution: CastSolution? = nil,
        motionPhase: RodMotionPhase = .invalid,
        castPower: Float = 0
    ) {
        self.timestamp = timestamp
        distance = spatial.distance
        directionX = spatial.directionX
        directionY = spatial.directionY
        directionZ = spatial.directionZ
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.orientation = orientation
        self.action = action
        self.reelSpeed = reelSpeed
        self.castSolution = castSolution
        self.motionPhase = motionPhase
        self.castPower = castPower
    }
}
