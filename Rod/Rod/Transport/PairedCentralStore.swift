//
//  PairedCentralStore.swift
//  Rod
//
//  Created by Calzy Akmal Indyramdhani on 20/07/26.
//

import Foundation

/// Persists the identity of the specific World central `TransportClient` is paired with, across
/// app launches, so Rod doesn't treat just any Mac that happens to subscribe as connected —
/// several Rods and Worlds can be in Bluetooth range of each other in the same room. `CBCentral`
/// exposes no display name (only an identifier), unlike `CBPeripheral` on World's side. Pairing is
/// captured automatically the first time a central subscribes (no dedicated pairing UI needed);
/// `forgetPairedDevice()` on `TransportClient` is the only way to clear it and re-pair with a
/// different Mac.
final class PairedCentralStore {

    private static let identifierKey = "rod.pairedCentralIdentifier"

    private(set) var identifier: UUID?

    init() {
        if let stored = UserDefaults.standard.string(forKey: Self.identifierKey) {
            identifier = UUID(uuidString: stored)
        }
    }

    func save(identifier: UUID) {
        self.identifier = identifier
        UserDefaults.standard.set(identifier.uuidString, forKey: Self.identifierKey)
    }

    func clear() {
        identifier = nil
        UserDefaults.standard.removeObject(forKey: Self.identifierKey)
    }
}
