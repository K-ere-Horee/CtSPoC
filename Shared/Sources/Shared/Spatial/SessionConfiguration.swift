//
//  SessionConfiguration.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation

/// GATT identifiers shared between Rod (BLE peripheral) and World (BLE central). Plain
/// `String`s, not `CBUUID`, so this stays importable from Shared without pulling in
/// CoreBluetooth (Shared must remain platform-agnostic).
public enum SessionConfiguration {

    /// The one custom service both sides look for.
    public static let bleServiceUUID = "6E9B0001-2B5A-4F1E-9C3D-2B1A6E9B0001"

    /// Rod -> World, notify, unreliable. Carries the ~30 Hz `RodState` stream. Never
    /// fragmented — a sample that doesn't fit one BLE packet is dropped, not queued, since a
    /// fresher one is always ~33 ms away (see `NetworkMessage.requiresReliableDelivery`).
    public static let bleStateCharacteristicUUID = "6E9B0002-2B5A-4F1E-9C3D-2B1A6E9B0001"

    /// Rod -> World, indicate, reliable. Carries `.discoveryToken`. May be fragmented
    /// (`BLEFraming`) across multiple indicates — indicate's own ack-per-packet flow control
    /// makes that safe, unlike the unreliable state characteristic above.
    public static let bleReliableOutCharacteristicUUID = "6E9B0003-2B5A-4F1E-9C3D-2B1A6E9B0001"

    /// World -> Rod, write-with-response, reliable. Carries `.fishingEvent`/`.hookPhase`. May
    /// be fragmented (`BLEFraming`) for the same reason as the characteristic above.
    public static let bleCommandCharacteristicUUID = "6E9B0004-2B5A-4F1E-9C3D-2B1A6E9B0001"

}
