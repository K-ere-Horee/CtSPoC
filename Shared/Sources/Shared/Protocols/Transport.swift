//
//  Transport.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation

public protocol TransportProtocol: AnyObject, Sendable {

    var isConnected: Bool { get }

    func connect() async throws

    func disconnect()

    func send(_ message: NetworkMessage) async throws
}
