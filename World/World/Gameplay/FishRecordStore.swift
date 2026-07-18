//
//  FishRecordStore.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 18/07/26.
//

import Foundation

/// Persists the heaviest catch per species across app launches, so
/// `FishFightController` can flag "New Record" on the result screen.
final class FishRecordStore {

    private static let storageKey = "world.fishRecords"

    private var bestWeightBySpeciesID: [String: Double]

    init() {
        bestWeightBySpeciesID = Self.load()
    }

    /// Records a catch. Returns `true` if it beat (or is the first of) the
    /// stored best weight for this species.
    @discardableResult
    func recordCatch(speciesID: String, weight: Double) -> Bool {
        if let previousBest = bestWeightBySpeciesID[speciesID], weight <= previousBest {
            return false
        }
        bestWeightBySpeciesID[speciesID] = weight
        save()
        return true
    }

    private static func load() -> [String: Double] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bestWeightBySpeciesID) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
