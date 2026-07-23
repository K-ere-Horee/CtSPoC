//
//  CaughtSpeciesStore.swift
//  Rod
//
//  Rod's local copy of which species the player has caught (ADR-128), received over transport
//  from World's own `FishRecordStore` (`NetworkMessage.caughtSpecies`, always the full set, never
//  a delta — see that case's own doc comment). Mirrors `FishRecordStore`'s own simple pattern:
//  a plain class instantiated wherever needed, reading/writing the same UserDefaults key, so
//  multiple instances (one in `RodViewModel` to receive updates, one in `FishPreviewViewModel` to
//  read them) stay in sync through shared storage rather than needing to be wired together
//  directly. `FishPreviewViewModel.species` (ADR-127) filters `FishCatalog.all` down to this set,
//  since the AR preview screen is meant to show only fish already caught, not the full catalog.
//

import Foundation

final class CaughtSpeciesStore {

    private static let storageKey = "rod.caughtSpecies"

    private(set) var caughtSpeciesIDs: Set<String>

    init() {
        caughtSpeciesIDs = Self.load()
    }

    /// Overwrites the local copy with the full set World just sent. Not additive — a species
    /// caught on a previous install/reset that World itself has since forgotten (e.g. after
    /// World's own progression reset) should disappear from Rod too, not linger forever.
    func replace(with ids: Set<String>) {
        caughtSpeciesIDs = ids
        save()
    }

    private static func load() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode(Set<String>.self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(caughtSpeciesIDs) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
