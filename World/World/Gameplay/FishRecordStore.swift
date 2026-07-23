//
//  FishRecordStore.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 18/07/26.
//

import Foundation

/// Persists the heaviest catch per species across app launches, so
/// `FishFightController` can flag "New Record" on the result screen.
///
/// ADR-119: also persists a running catch *count* per species (`catchCountBySpeciesID`) —
/// distinct from the best-weight tracking above, and from `ProgressionStore`'s tier-level counts
/// (small/medium/big/boss) — added specifically for the new species-progress HUD ("progressionnya
/// diganti jangan pake standar Fish A Fish B lagi, tapi sesuai jenis ikan aja... udah nangkep ikan
/// jenis apa berapa, dan target setiap ikan berapa").
final class FishRecordStore {

    private static let storageKey = "world.fishRecords"
    private static let catchCountStorageKey = "world.fishCatchCounts"

    private var bestWeightBySpeciesID: [String: Double]
    private var catchCountBySpeciesID: [String: Int]

    init() {
        bestWeightBySpeciesID = Self.load()
        catchCountBySpeciesID = Self.loadCounts()
    }

    /// Every species ID ever caught (ADR-111) — this store's keys already are exactly that set,
    /// so this is just a typed view over them. Sent to Rod (`NetworkMessage.caughtSpecies`) so its
    /// standalone AR fish-preview screen can list only species actually caught.
    var caughtSpeciesIDs: Set<String> {
        Set(bestWeightBySpeciesID.keys)
    }

    /// Records a catch. Returns `true` if it beat (or is the first of) the
    /// stored best weight for this species. Always increments the species' catch count,
    /// regardless of whether it's a new record.
    @discardableResult
    func recordCatch(speciesID: String, weight: Double) -> Bool {
        catchCountBySpeciesID[speciesID, default: 0] += 1
        saveCounts()

        if let previousBest = bestWeightBySpeciesID[speciesID], weight <= previousBest {
            return false
        }
        bestWeightBySpeciesID[speciesID] = weight
        save()
        return true
    }

    /// How many of this species have been caught so far — the species-progress HUD's "caught"
    /// half of its "caught/target" display.
    func catchCount(for speciesID: String) -> Int {
        catchCountBySpeciesID[speciesID] ?? 0
    }

    /// Clears every species' catch count (not the best-weight records — those stay as a permanent
    /// personal-best log) — called alongside `ProgressionStore.reset()` so the species checklist
    /// starts fresh together with tier progression on a full reset.
    func resetCounts() {
        catchCountBySpeciesID = [:]
        saveCounts()
    }

    private static func load() -> [String: Double] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bestWeightBySpeciesID) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func loadCounts() -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: catchCountStorageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }

    private func saveCounts() {
        guard let data = try? JSONEncoder().encode(catchCountBySpeciesID) else { return }
        UserDefaults.standard.set(data, forKey: Self.catchCountStorageKey)
    }
}
