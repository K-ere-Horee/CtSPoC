//
//  HookPhase.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 15/07/26.
//

import Foundation

public enum HookPhase: String, Codable, Sendable {

    case idle
    case flying
    case hookInWater
    case reeling
}

public extension HookPhase {
    var allowsCasting: Bool { self == .idle }
    var allowsReeling: Bool { self == .hookInWater || self == .reeling }
}
