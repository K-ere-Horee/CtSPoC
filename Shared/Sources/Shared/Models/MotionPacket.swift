//
//  MotionPacket.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation

public struct MotionPacket: Codable, Sendable {

    public let timestamp: TimeInterval

    public let pitch: Double
    public let roll: Double
    public let yaw: Double

    public init(
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        pitch: Double,
        roll: Double,
        yaw: Double
    ) {
        self.timestamp = timestamp
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
    }
}
