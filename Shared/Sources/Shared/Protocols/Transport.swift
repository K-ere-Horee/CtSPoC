//
//  Transport.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation

/// `@MainActor`: both conformers (`TransportClient`/`TransportHost`) wrap CoreBluetooth managers
/// configured to callback on the main queue, and both call sites (`RodViewModel`/`WorldViewModel`)
/// are themselves `@MainActor` — isolating the protocol here documents and enforces that instead
/// of leaving it implicit, avoiding a real actor-isolation-crossing warning (a hard error under
/// Swift 6) on every conforming type.
@MainActor
public protocol TransportProtocol: AnyObject {

    var isConnected: Bool { get }

    func connect() async throws

    func disconnect()

    func send(_ message: NetworkMessage) async throws
}
