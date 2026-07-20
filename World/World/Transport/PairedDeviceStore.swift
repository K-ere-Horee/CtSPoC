//
//  PairedDeviceStore.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 20/07/26.
//

import Foundation

/// Persists the identity of the specific Rod peripheral `TransportHost` is paired with, across
/// app launches, so World doesn't auto-connect to whichever Rod happens to be discovered first —
/// several Rods and Worlds can be in Bluetooth range of each other in the same room. Pairing is
/// captured automatically the first time a connection fully succeeds (no dedicated pairing UI
/// needed); `forgetPairedDevice()` on `TransportHost` is the only way to clear it and re-pair with
/// a different device.
final class PairedDeviceStore {

    private static let identifierKey = "world.pairedRodIdentifier"
    private static let nameKey = "world.pairedRodName"

    private(set) var identifier: UUID?
    private(set) var name: String?

    init() {
        if let stored = UserDefaults.standard.string(forKey: Self.identifierKey) {
            identifier = UUID(uuidString: stored)
        }
        name = UserDefaults.standard.string(forKey: Self.nameKey)
    }

    func save(identifier: UUID, name: String?) {
        self.identifier = identifier
        self.name = name
        UserDefaults.standard.set(identifier.uuidString, forKey: Self.identifierKey)
        if let name {
            UserDefaults.standard.set(name, forKey: Self.nameKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.nameKey)
        }
    }

    func clear() {
        identifier = nil
        name = nil
        UserDefaults.standard.removeObject(forKey: Self.identifierKey)
        UserDefaults.standard.removeObject(forKey: Self.nameKey)
    }
}
