//
//  FishCatalog.swift
//  Shared
//
//  Promoted from World/World/Gameplay/FishCatalog.swift (ADR-032) so World's
//  catch simulation and Rod's standalone AR fish preview screen share one
//  source of truth. Weight, resistance, and value are first-pass gameplay
//  approximations pending balancing, not exact biological data; biology text
//  is sourced from the asset repo's per-species Scientific_Validation.md.
//
//  Note: promoting this catalog also expands World's live catch roster from
//  the single placeholder "Fish A" to these 8 real species — an intentional
//  side effect of this move, not an incidental one.
//

import Foundation

/// The available species pool. World selects from this pool when a fish
/// bites; Rod's AR preview screen (ADR-032) lists every entry regardless of
/// catch history, since preview is independent of the Connect->Cast->Catch
/// loop. Add more species by appending to `all`.
public enum FishCatalog {
    public static let all: [FishSpecies] = [
        FishSpecies(
            id: "skipjack_tuna",
            name: "Skipjack Tuna",
            weightRange: FishSpeciesRange(min: 3, max: 12),
            lengthRange: FishSpeciesRange(min: 60, max: 90),
            resistance: 0.40,
            value: 60,
            scientificName: "Katsuwonus pelamis",
            rarity: .common,
            description: "A fast, schooling tuna found in tropical and subtropical waters worldwide, identifiable by four to six dark stripes running along its lower flanks. It's a thunniform swimmer, holding its body stiff and cruising almost constantly on tail-peduncle thrust alone.",
            previewAssetName: "skipjack_tuna",
            attribution: nil
        ),
        FishSpecies(
            id: "grouper",
            name: "Grouper",
            weightRange: FishSpeciesRange(min: 2, max: 8),
            lengthRange: FishSpeciesRange(min: 30, max: 60),
            resistance: 0.30,
            value: 40,
            scientificName: "Epinephelus awoara",
            rarity: .common,
            description: "A stout, deep-bodied reef ambush predator with a large head and mouth, mottled orange-brown skin, and dense yellow-orange spotting. Rather than chasing prey, it lies in wait and strikes with a sudden, wide-mouthed suction-feeding lunge.",
            previewAssetName: "grouper",
            attribution: nil
        ),
        FishSpecies(
            id: "giant_trevally",
            name: "Giant Trevally",
            weightRange: FishSpeciesRange(min: 15, max: 50),
            lengthRange: FishSpeciesRange(min: 80, max: 150),
            resistance: 0.65,
            value: 150,
            scientificName: "Caranx ignobilis",
            rarity: .rare,
            description: "The largest member of the jack family, ranging across Indo-Pacific lagoons and seaward reefs, with adult males famously darkening to near jet-black. An opportunistic hunter of crustaceans and fish, it's built for bursts of speed with a steep head profile and sickle-shaped pectoral fins.",
            previewAssetName: "giant_trevally",
            attribution: nil
        ),
        FishSpecies(
            id: "yellowfin_tuna",
            name: "Yellowfin Tuna",
            weightRange: FishSpeciesRange(min: 30, max: 120),
            lengthRange: FishSpeciesRange(min: 120, max: 200),
            resistance: 0.70,
            value: 200,
            scientificName: "Thunnus albacares",
            rarity: .rare,
            description: "Named for its bright yellow, black-edged finlets and long, sickle-shaped second dorsal and anal fins, this metallic-blue tuna is one of the most heavily fished tropical tunas in the world. Like its relatives, it swims with a nearly rigid body, driven almost entirely by its tail.",
            previewAssetName: "yellowfin_tuna",
            attribution: nil
        ),
        FishSpecies(
            id: "sailfish",
            name: "Sailfish",
            weightRange: FishSpeciesRange(min: 25, max: 60),
            lengthRange: FishSpeciesRange(min: 200, max: 280),
            resistance: 0.80,
            value: 350,
            scientificName: "Istiophorus platypterus",
            rarity: .epic,
            description: "Recognized instantly by its towering, sail-like first dorsal fin and long spear-shaped bill, the sailfish is among the fastest fish in the ocean and a prized Indo-Pacific game species. Dark blue-black above with a silvery belly and shimmering blue bars, it runs down baitfish in fast, aggressive pursuits.",
            previewAssetName: "sailfish",
            attribution: "\"Sailfish\" by Mateus Schwaab, licensed under CC-BY, via Sketchfab."
        ),
        FishSpecies(
            id: "bluefin_tuna",
            name: "Atlantic Bluefin Tuna",
            weightRange: FishSpeciesRange(min: 100, max: 300),
            lengthRange: FishSpeciesRange(min: 150, max: 250),
            resistance: 0.85,
            value: 400,
            scientificName: "Thunnus thynnus",
            rarity: .epic,
            description: "A massive, torpedo-shaped tuna capable of regulating its own body temperature above the surrounding water, letting it range from tropical seas to near-freezing Atlantic waters. Black-edged yellow finlets, a crescent tail, and three caudal keels mark this endangered, heavily migratory species.",
            previewAssetName: "bluefin_tuna",
            attribution: "\"Bluefin Tuna\" by dhjwdwd, licensed under CC-BY, via Sketchfab."
        ),
        FishSpecies(
            id: "mekong_giant_catfish",
            name: "Mekong Giant Catfish",
            weightRange: FishSpeciesRange(min: 150, max: 300),
            lengthRange: FishSpeciesRange(min: 200, max: 270),
            resistance: 0.90,
            value: 450,
            scientificName: "Pangasianodon gigas",
            rarity: .epic,
            description: "One of the largest freshwater fish on Earth, this critically endangered, scaleless catfish is native to the Mekong River basin and can top 250 kilograms. Uniquely for a catfish, adults lose their teeth and barbels entirely and graze on algae and plant matter rather than hunting prey.",
            previewAssetName: "mekong_giant_catfish",
            attribution: "\"Ikan Patin\" (Sketchfab, UID d9e7f483…), licensed under CC-BY 4.0."
        ),
        FishSpecies(
            id: "blue_marlin",
            name: "Blue Marlin",
            weightRange: FishSpeciesRange(min: 120, max: 400),
            lengthRange: FishSpeciesRange(min: 250, max: 400),
            resistance: 0.95,
            value: 500,
            scientificName: "Makaira nigricans",
            rarity: .legendary,
            description: "A powerful, circumtropical billfish with a long spear-shaped bill, cobalt-blue back, and rows of pale spots along its flanks, prized as one of the ocean's premier big-game species. Its unusually high nape and rigid, laterally flexing body let it cruise slowly for long stretches before short, explosive bursts of speed.",
            previewAssetName: "blue_marlin",
            attribution: "\"Blue Marlin\" by Gotta_go_evil_Fast, licensed under CC-BY 4.0, via Sketchfab."
        )
    ]

    public static func randomSpecies() -> FishSpecies {
        all.randomElement() ?? all[0]
    }
}
