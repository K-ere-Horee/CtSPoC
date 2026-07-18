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
enum FishCatalog {
    static let all: [FishSpecies] = [
        FishSpecies(
            id: "fish_a",
            name: "Fish A",
            weightRange: FishSpeciesRange(min: 0.8, max: 3.5),
            lengthRange: FishSpeciesRange(min: 20, max: 55),
            resistance: 0.35,
            value: 10
        )
    ]

    static func randomSpecies() -> FishSpecies {
        all.randomElement() ?? all[0]
    }
}
