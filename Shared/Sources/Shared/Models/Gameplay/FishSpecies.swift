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

/// Progression tier a species belongs to. `ProgressionStore` gates which tiers are catchable;
/// see `GAMEPLAY_ARCHITECTURE_V1.md`'s "Fish and Progression Systems" section and ADR-037.
/// `.boss` is Scott specifically, not just "the biggest regular fish" — a distinct, singular
/// encounter unlocked once alongside `.big`, not part of the same random-weight progression that
/// `.small`/`.medium`/`.big` scale through.
public enum FishTier: String, Codable, Sendable, CaseIterable {
    case small
    case medium
    case big
    case boss
}

/// Static per-species gameplay data. World selects a species when a fish
/// bites and applies its modifiers to bite grace period, line tension, and
/// catch value. Also carries presentation metadata for Rod's AR preview
/// screen (ADR-032).
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
    /// Which progression tier gates this species' availability.
    public let tier: FishTier
    public let scientificName: String
    public let rarity: FishRarity
    public let description: String
    /// Named of the `.usdz` preview asset in the app bundle (without `.usdz`).
    /// `nil` means no preview model is available for this species.
    public let previewAssetName: String?
    /// Required CC-BY attribution text, if any. `nil` if no attribution needed.
    public let attribution: String?

    public init(
        id: String,
        name: String,
        weightRange: FishSpeciesRange,
        lengthRange: FishSpeciesRange,
        resistance: Double,
        value: Int,
        tier: FishTier,
        scientificName: String = "",
        rarity: FishRarity = .common,
        description: String = "",
        previewAssetName: String? = nil,
        attribution: String? = nil
    ) {
        self.id = id
        self.name = name
        self.weightRange = weightRange
        self.lengthRange = lengthRange
        self.resistance = min(1, max(0, resistance))
        self.value = value
        self.tier = tier
        self.scientificName = scientificName
        self.rarity = rarity
        self.description = description
        self.previewAssetName = previewAssetName
        self.attribution = attribution
    }
}
