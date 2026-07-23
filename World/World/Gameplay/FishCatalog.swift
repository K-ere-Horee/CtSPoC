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
/// ADR-118: replaced the four `fish_a`/`fish_b`/`fish_c`/`scott` placeholders with 8 real species
/// backed by real `.usdz` assets — every species in `K-ere-Horee/blender-assets`'s `FishAssets/`
/// that has a `Caught/*.usdz` export (Clownfish/Blue Tang are excluded: `.glb` only, no `.usdz`,
/// per that repo's own `APP_TEAM_HANDOFF.md`). `weightRange`/`lengthRange` are built from each
/// species' own `Documentation/Scientific_Validation.md` (real-world max/common length, where
/// weight data existed) scaled down to a plausible catchable range — same "rough scale-up, not
/// tuned" placeholder status the original four had (per this comment's own prior wording); the one
/// firm rule carried forward is still higher tier = harder on weight, length, and resistance.
/// `authoredLength` comes from each species' `Documentation/Source_Log.md` (the actual meters its
/// mesh was scaled to at export), not the `Scientific_Validation.md` "Model Length" field, which
/// documents an earlier design target that isn't always what shipped.
///
/// ADR-119: `catchTarget` (how many of this species the species-progress HUD counts toward) is
/// flat per tier — small 5, medium 4, big 3, boss 1 — matching the "rarer tier = fewer needed"
/// shape `ProgressionStore`'s own tier thresholds already use, not independently tuned per species.
enum FishCatalog {
    static let all: [FishSpecies] = [
        FishSpecies(
            id: "grouper",
            name: "Grouper",
            weightRange: FishSpeciesRange(min: 0.5, max: 2.5),
            lengthRange: FishSpeciesRange(min: 25, max: 50),
            resistance: 0.25,
            value: 8,
            tier: .small,
            assetName: "grouper_caught",
            authoredLength: 0.6,
            catchTarget: 5
        ),
        FishSpecies(
            id: "skipjack_tuna",
            name: "Skipjack Tuna",
            weightRange: FishSpeciesRange(min: 2.0, max: 8.0),
            lengthRange: FishSpeciesRange(min: 40, max: 80),
            resistance: 0.40,
            value: 15,
            tier: .small,
            assetName: "skipjack_tuna_caught",
            authoredLength: 0.9,
            catchTarget: 5
        ),
        FishSpecies(
            id: "giant_trevally",
            name: "Giant Trevally",
            weightRange: FishSpeciesRange(min: 5.0, max: 18.0),
            lengthRange: FishSpeciesRange(min: 70, max: 130),
            resistance: 0.55,
            value: 35,
            tier: .medium,
            assetName: "giant_trevally_caught",
            authoredLength: 1.2,
            catchTarget: 4
        ),
        FishSpecies(
            id: "yellowfin_tuna",
            name: "Yellowfin Tuna",
            weightRange: FishSpeciesRange(min: 10.0, max: 30.0),
            lengthRange: FishSpeciesRange(min: 100, max: 180),
            resistance: 0.60,
            value: 50,
            tier: .medium,
            assetName: "yellowfin_tuna_caught",
            authoredLength: 2.0,
            catchTarget: 4
        ),
        FishSpecies(
            id: "mekong_giant_catfish",
            name: "Mekong Giant Catfish",
            weightRange: FishSpeciesRange(min: 20.0, max: 45.0),
            lengthRange: FishSpeciesRange(min: 140, max: 220),
            resistance: 0.65,
            value: 80,
            tier: .big,
            assetName: "mekong_catfish_caught",
            authoredLength: 2.0,
            catchTarget: 3
        ),
        // ADR-120: "bluefin tuna kebalik orientasinya waktu fish catch" — renders head-down under
        // the shared cutscene orientation everyone else uses correctly; see
        // `catchOrientationFlipped`'s own doc comment.
        FishSpecies(
            id: "bluefin_tuna",
            name: "Bluefin Tuna",
            weightRange: FishSpeciesRange(min: 30.0, max: 70.0),
            lengthRange: FishSpeciesRange(min: 180, max: 280),
            resistance: 0.75,
            value: 120,
            tier: .big,
            assetName: "bluefin_tuna_caught",
            authoredLength: 3.0,
            catchTarget: 3,
            catchOrientationFlipped: true
        ),
        FishSpecies(
            id: "marlin",
            name: "Blue Marlin",
            weightRange: FishSpeciesRange(min: 40.0, max: 90.0),
            lengthRange: FishSpeciesRange(min: 200, max: 320),
            resistance: 0.80,
            value: 150,
            tier: .big,
            assetName: "marlin_caught",
            authoredLength: 3.0,
            catchTarget: 3
        ),
        // ADR-118: the boss encounter — requested directly, "jadiin Sailfish as Scott the
        // ultimate boss." Keeps the established `name: "Scott"` (the game's own singular boss
        // character, per the title screen/tutorial/mascot art referencing "Scott" throughout),
        // now backed by the Sailfish species' real weight/length data and 3D asset instead of a
        // nameless placeholder.
        FishSpecies(
            id: "sailfish",
            name: "Scott",
            weightRange: FishSpeciesRange(min: 50.0, max: 100.0),
            lengthRange: FishSpeciesRange(min: 250, max: 350),
            resistance: 0.85,
            value: 500,
            tier: .boss,
            assetName: "sailfish_caught",
            authoredLength: 2.72,
            catchTarget: 1
        )
    ]

    /// Picks a random species from only the tiers `unlockedTiers` allows — `ProgressionStore`
    /// decides which tiers those are. Falls back to `all[0]` (`grouper`, always unlocked) if the
    /// filtered pool is somehow empty, so a bite never fails to resolve.
    static func randomSpecies(unlockedTiers: Set<FishTier>) -> FishSpecies {
        let pool = all.filter { unlockedTiers.contains($0.tier) }
        return pool.randomElement() ?? all[0]
    }
}
