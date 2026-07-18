//
//  SpatialStatus.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation

public enum SpatialStatus: String, Codable, Sendable {
    case unavailable
    case searching
    case ready
    case updating
    case failed
}
