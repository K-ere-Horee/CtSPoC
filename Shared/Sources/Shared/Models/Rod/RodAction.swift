//
//  RodAction.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation

/// Intent inferred from the physical Rod controller.
public enum RodAction: String, Codable, Sendable, Equatable {
    case idle
    case casting
    case reeling
}
