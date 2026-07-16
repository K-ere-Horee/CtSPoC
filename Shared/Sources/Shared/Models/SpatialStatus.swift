//
//  SpatialStatus.swift
//  Shared
//

import Foundation

public enum SpatialStatus: String, Codable, Sendable {
    case unavailable
    case searching
    case ready
    case updating
    case failed
}
