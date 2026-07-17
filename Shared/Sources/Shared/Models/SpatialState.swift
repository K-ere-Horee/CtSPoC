//
//  SpatialState.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation

/// Relative position reported by Nearby Interaction.
public struct SpatialState: Codable, Sendable, Equatable {

    public let distance: Float?
    public let directionX: Float?
    public let directionY: Float?
    public let directionZ: Float?

    public init(
        distance: Float? = nil,
        directionX: Float? = nil,
        directionY: Float? = nil,
        directionZ: Float? = nil
    ) {
        self.distance = distance
        self.directionX = directionX
        self.directionY = directionY
        self.directionZ = directionZ
    }
}
