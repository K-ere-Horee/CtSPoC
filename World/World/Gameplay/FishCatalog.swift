//
//  FishCatalog.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 18/07/26.
//

import Shared

/// The available species pool. World owns fish selection; each entry's base
/// modifiers can be retuned here without touching fight logic. Add more
/// species by appending to `all`.
///
/// Tier placeholders (`fish_b`/`fish_c`/`scott`, ADR-037): weight/length/resistance/value are
/// rough scale-ups from `fish_a`, not tuned — the player's own framing was "parameter fish nya
/// nanti di ubah lagi seiring berjalannya game" (fish parameters will be adjusted again as the
/// game progresses), with the one firm rule being higher tier = harder on weight, length, and
/// resistance. Retune freely; this is a placeholder ordering, not a balanced one.
enum FishCatalog {
    static let all: [FishSpecies] = [
        FishSpecies(
            id: "fish_a",
            name: "Fish A",
            weightRange: FishSpeciesRange(min: 0.8, max: 3.5),
            lengthRange: FishSpeciesRange(min: 20, max: 55),
            resistance: 0.35,
            value: 10,
            tier: .small
        ),
        FishSpecies(
            id: "fish_b",
            name: "Fish B",
            weightRange: FishSpeciesRange(min: 3.5, max: 9.0),
            lengthRange: FishSpeciesRange(min: 55, max: 90),
            resistance: 0.50,
            value: 25,
            tier: .medium
        ),
        FishSpecies(
            id: "fish_c",
            name: "Fish C",
            weightRange: FishSpeciesRange(min: 9.0, max: 20.0),
            lengthRange: FishSpeciesRange(min: 90, max: 140),
            // Eased further after ADR-054's initial 0.75 -> 0.60 pass (requested directly:
            // "mudahin dikit dong ikan level 3 dan 4 nya") to 0.10, alongside fish_b.
            resistance: 0.65,
            value: 60,
            tier: .big
        ),
        FishSpecies(
            id: "scott",
            name: "Scott",
            weightRange: FishSpeciesRange(min: 20.0, max: 40.0),
            lengthRange: FishSpeciesRange(min: 140, max: 200),
            // Eased further after ADR-054's initial 0.95 -> 0.75 pass to 0.10, same request as
            // fish_c above.
            resistance: 0.70,
            value: 500,
            tier: .boss
        )
    ]

    /// Picks a random species from only the tiers `unlockedTiers` allows — `ProgressionStore`
    /// decides which tiers those are. Falls back to `all[0]` (`fish_a`, always unlocked) if the
    /// filtered pool is somehow empty, so a bite never fails to resolve.
    static func randomSpecies(unlockedTiers: Set<FishTier>) -> FishSpecies {
        let pool = all.filter { unlockedTiers.contains($0.tier) }
        return pool.randomElement() ?? all[0]
    }
}
