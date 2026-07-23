//
//  FishRarity.swift
//  Shared
//

import Foundation

public enum FishRarity: String, Codable, Sendable, Equatable, CaseIterable {
    case common
    case rare
    case epic
    case legendary

    public var displayName: String { rawValue.capitalized }
}
