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
    case fishOnHook
    case reeling
    /// A catch just resolved and World is showing the result screen. The
    /// player must dismiss it (World's "Continue Fishing") before the next
    /// cast is allowed.
    case result
}

public extension HookPhase {
    var allowsCasting: Bool { self == .idle }
    var allowsReeling: Bool { self == .hookInWater || self == .fishOnHook || self == .reeling }
}
