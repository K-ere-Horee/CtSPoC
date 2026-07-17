//
//  RodAction.swift
//  Shared
//

import Foundation

/// Intent inferred from the physical Rod controller.
public enum RodAction: String, Codable, Sendable, Equatable {
    case idle
    case casting
    case reeling
}
