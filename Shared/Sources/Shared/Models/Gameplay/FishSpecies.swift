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
/// catch value. ADR-118: `assetName`/`authoredLength` wire this to a real 3D
/// model for the catch cutscene, once optional/absent, now populated for
/// every species `FishCatalog` defines.
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
    /// ADR-118: base filename (no extension) of this species' `Caught`-state `.usdz`, e.g.
    /// `"sailfish_caught"` for `World/World/Assets/FishCaught/sailfish_caught.usdz`. World loads
    /// one entity per species up front from this name; the catch cutscene picks the right one by
    /// matching `FishCatchResult.speciesID` back to this `FishSpecies.id`.
    public let assetName: String
    /// ADR-118: real-world meters the asset's mesh was scaled to at export (each species'
    /// `Documentation/Source_Log.md` in the `blender-assets` repo's `FishAssets/` — e.g. Sailfish
    /// was "Rescaled to 2.72 m"). World divides the actual rolled catch length by this to compute
    /// the cutscene display scale, replacing a single asset-specific constant that only worked for
    /// one hardcoded species.
    public let authoredLength: Float
    /// ADR-119: how many of this species the species-progress HUD counts toward before showing it
    /// as "complete" — a per-species checklist goal, replacing the old tier-only ("Fish A/Fish B")
    /// progress display with something tied to real species identity, per direct request:
    /// "progressionnya diganti jangan pake standar Fish A Fish B lagi, tapi sesuai jenis ikan aja."
    public let catchTarget: Int
    /// ADR-120: `true` if this species' `Caught` asset renders head-down/upside-down under the
    /// shared `catchCutsceneFishOrientation` convention (local -Y = head, per the source repo's
    /// documented "length along local Y" export standard) — reported directly for Bluefin Tuna
    /// ("bluefin tuna kebalik orientasinya waktu fish catch"). World negates the head-axis mapping
    /// for any species with this set, instead of hand-patching the shared orientation for
    /// everyone. `false` for every other species, none of which have been reported as flipped.
    public let catchOrientationFlipped: Bool

    public init(
        id: String,
        name: String,
        weightRange: FishSpeciesRange,
        lengthRange: FishSpeciesRange,
        resistance: Double,
        value: Int,
        tier: FishTier,
        assetName: String,
        authoredLength: Float,
        catchTarget: Int,
        catchOrientationFlipped: Bool = false
    ) {
        self.id = id
        self.name = name
        self.weightRange = weightRange
        self.lengthRange = lengthRange
        self.resistance = min(1, max(0, resistance))
        self.value = value
        self.tier = tier
        self.assetName = assetName
        self.authoredLength = authoredLength
        self.catchTarget = catchTarget
        self.catchOrientationFlipped = catchOrientationFlipped
    }
}
