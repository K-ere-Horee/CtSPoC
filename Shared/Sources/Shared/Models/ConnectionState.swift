//
//  ConnectionState.swift
//  Shared
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
