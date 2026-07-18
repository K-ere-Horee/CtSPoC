//
//  FishSpecies.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 18/07/26.
//

import Foundation

/// An inclusive numeric range that survives `Codable`, unlike `ClosedRange`.
public struct FishSpeciesRange: Codable, Sendable, Equatable {
    public let min: Double
    public let max: Double

    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }

    public func randomValue() -> Double {
        Double.random(in: min...max)
    }
}

/// Static per-species gameplay data. World selects a species when a fish
/// bites and applies its modifiers to bite grace period, line tension, and
/// catch value. Asset/mesh selection is intentionally not part of this
/// model yet; it will be added once 3D fish assets exist.
public struct FishSpecies: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let weightRange: FishSpeciesRange
    public let lengthRange: FishSpeciesRange
    /// 0 (weak) ... 1 (extreme). Scales how quickly line tension builds and
    /// how little time the player has to react to a bite before it escapes.
    public let resistance: Double
    /// Coins/points awarded on a successful catch.
    public let value: Int

    public init(
        id: String,
        name: String,
        weightRange: FishSpeciesRange,
        lengthRange: FishSpeciesRange,
        resistance: Double,
        value: Int
    ) {
        self.id = id
        self.name = name
        self.weightRange = weightRange
        self.lengthRange = lengthRange
        self.resistance = min(1, max(0, resistance))
        self.value = value
    }
}
