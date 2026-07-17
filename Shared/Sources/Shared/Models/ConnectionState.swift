//
//  ConnectionState.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 15/07/26.
//

import Foundation

public enum ConnectionState: String, Codable, Sendable {
    case idle
    case searching
    case connecting
    case ready
    case streaming
    case disconnected
    case failed
}
