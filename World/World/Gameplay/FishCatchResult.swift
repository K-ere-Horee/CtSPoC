//
//  FishCatchResult.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 18/07/26.
//

/// The resolved outcome of a single bite, for HUD display only.
struct FishCatchResult: Equatable {
    enum Outcome: String {
        case caught = "Caught"
        case escaped = "Escaped"
        case lineBreak = "Line Broke"
    }

    let speciesName: String
    let weight: Double
    let length: Double
    let outcome: Outcome
}
