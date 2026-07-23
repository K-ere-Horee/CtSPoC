//
//  FishCatalog.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 18/07/26.
//
//  Promoted from World/World/Gameplay/FishCatalog.swift (ADR-127) so World's catch simulation and
//  Rod's standalone AR fish preview screen share one source of truth.
//
//  ADR-118: replaced the four `fish_a`/`fish_b`/`fish_c`/`scott` placeholders with 8 real species
//  backed by real `.usdz` assets — every species in `K-ere-Horee/blender-assets`'s `FishAssets/`
//  that has a `Caught/*.usdz` export (Clownfish/Blue Tang are excluded: `.glb` only, no `.usdz`,
//  per that repo's own `APP_TEAM_HANDOFF.md`). `weightRange`/`lengthRange` are built from each
//  species' own `Documentation/Scientific_Validation.md` (real-world max/common length, where
//  weight data existed) scaled down to a plausible catchable range — "rough scale-up, not tuned"
//  placeholder status; the one firm rule carried forward is higher tier = harder on weight,
//  length, and resistance. `authoredLength` comes from each species' `Documentation/Source_Log.md`
//  (the actual meters its mesh was scaled to at export), not the `Scientific_Validation.md` "Model
//  Length" field, which documents an earlier design target that isn't always what shipped. Sailfish
//  is the game's namesake `.boss` encounter directly — "jadiin Sailfish as Scott the ultimate
//  boss" — not a separate placeholder alongside it.
//
//  ADR-119: `catchTarget` (how many of this species the species-progress HUD counts toward) is
//  flat per tier — small 5, medium 4, big 3, boss 1 — matching the "rarer tier = fewer needed"
//  shape `ProgressionStore`'s own tier thresholds already use, not independently tuned per species.
//
//  ADR-130: merged in Rod's AR fish preview presentation metadata (`scientificName`/`rarity`/
//  `description`/`previewAssetName`/`attribution`), matched onto this roster by species `id`.
//  `previewAssetName` points at `Rod/Rod/Assets/FishPreview/*.usdz`, which is exported/named
//  independently of `assetName`'s `Caught`-state asset (e.g. "marlin"'s preview file is
//  `blue_marlin.usdz`, not `marlin.usdz`) — the two filenames are allowed to disagree with each
//  other and with `id`.
//
public enum FishCatalog {
    public static let all: [FishSpecies] = [
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
            catchTarget: 5,
            scientificName: "Epinephelus awoara",
            rarity: .common,
            description: "A stout, deep-bodied reef ambush predator with a large head and mouth, mottled orange-brown skin, and dense yellow-orange spotting. Rather than chasing prey, it lies in wait and strikes with a sudden, wide-mouthed suction-feeding lunge.",
            previewAssetName: "grouper",
            attribution: nil
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
            catchTarget: 5,
            scientificName: "Katsuwonus pelamis",
            rarity: .common,
            description: "A fast, schooling tuna found in tropical and subtropical waters worldwide, identifiable by four to six dark stripes running along its lower flanks. It's a thunniform swimmer, holding its body stiff and cruising almost constantly on tail-peduncle thrust alone.",
            previewAssetName: "skipjack_tuna",
            attribution: nil
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
            catchTarget: 4,
            scientificName: "Caranx ignobilis",
            rarity: .rare,
            description: "The largest member of the jack family, ranging across Indo-Pacific lagoons and seaward reefs, with adult males famously darkening to near jet-black. An opportunistic hunter of crustaceans and fish, it's built for bursts of speed with a steep head profile and sickle-shaped pectoral fins.",
            previewAssetName: "giant_trevally",
            attribution: nil
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
            catchTarget: 4,
            scientificName: "Thunnus albacares",
            rarity: .rare,
            description: "Named for its bright yellow, black-edged finlets and long, sickle-shaped second dorsal and anal fins, this metallic-blue tuna is one of the most heavily fished tropical tunas in the world. Like its relatives, it swims with a nearly rigid body, driven almost entirely by its tail.",
            previewAssetName: "yellowfin_tuna",
            attribution: nil
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
            catchTarget: 3,
            scientificName: "Pangasianodon gigas",
            rarity: .epic,
            description: "One of the largest freshwater fish on Earth, this critically endangered, scaleless catfish is native to the Mekong River basin and can top 250 kilograms. Uniquely for a catfish, adults lose their teeth and barbels entirely and graze on algae and plant matter rather than hunting prey.",
            previewAssetName: "mekong_giant_catfish",
            attribution: "\"Ikan Patin\" (Sketchfab, UID d9e7f483…), licensed under CC-BY 4.0."
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
            catchOrientationFlipped: true,
            scientificName: "Thunnus thynnus",
            rarity: .epic,
            description: "A massive, torpedo-shaped tuna capable of regulating its own body temperature above the surrounding water, letting it range from tropical seas to near-freezing Atlantic waters. Black-edged yellow finlets, a crescent tail, and three caudal keels mark this endangered, heavily migratory species.",
            previewAssetName: "bluefin_tuna",
            attribution: "\"Bluefin Tuna\" by dhjwdwd, licensed under CC-BY, via Sketchfab."
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
            catchTarget: 3,
            scientificName: "Makaira nigricans",
            rarity: .legendary,
            description: "A powerful, circumtropical billfish with a long spear-shaped bill, cobalt-blue back, and rows of pale spots along its flanks, prized as one of the ocean's premier big-game species. Its unusually high nape and rigid, laterally flexing body let it cruise slowly for long stretches before short, explosive bursts of speed.",
            previewAssetName: "blue_marlin",
            attribution: "\"Blue Marlin\" by Gotta_go_evil_Fast, licensed under CC-BY 4.0, via Sketchfab."
        ),
        // ADR-118: the boss encounter — requested directly, "jadiin Sailfish as Scott the
        // ultimate boss." Keeps the established `name: "Scott"` (the game's own singular boss
        // character, per the title screen/tutorial/mascot art referencing "Scott" throughout),
        // now backed by the Sailfish species' real weight/length data and 3D asset instead of a
        // nameless placeholder. Still biologically a sailfish, so the preview card's scientific
        // name/description/attribution below are Sailfish's real ones.
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
            catchTarget: 1,
            scientificName: "Istiophorus platypterus",
            rarity: .legendary,
            description: "Recognized instantly by its towering, sail-like first dorsal fin and long spear-shaped bill, the sailfish is among the fastest fish in the ocean and a prized Indo-Pacific game species. Dark blue-black above with a silvery belly and shimmering blue bars, it runs down baitfish in fast, aggressive pursuits.",
            previewAssetName: "sailfish",
            attribution: "\"Sailfish\" by Mateus Schwaab, licensed under CC-BY, via Sketchfab."
        )
    ]

    /// Picks a random species from only the tiers `unlockedTiers` allows — `ProgressionStore`
    /// decides which tiers those are. Falls back to `all[0]` (`grouper`, always unlocked) if the
    /// filtered pool is somehow empty, so a bite never fails to resolve.
    public static func randomSpecies(unlockedTiers: Set<FishTier>) -> FishSpecies {
        let pool = all.filter { unlockedTiers.contains($0.tier) }
        return pool.randomElement() ?? all[0]
    }
}
