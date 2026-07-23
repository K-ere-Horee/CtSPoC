//
//  TransportClient.swift
//  Rod
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import CoreBluetooth
import Foundation
import Shared

/// Rod is the BLE **peripheral**: it advertises the fishing-rod GATT service and pushes
/// `RodState`/one-shot events to whichever central (World) subscribes, mirroring the previous
/// MultipeerConnectivity "client" role (the side that actively broadcasts itself).
///
/// `@MainActor` because the peripheral manager is constructed with `queue: nil` (main queue),
/// so every CoreBluetooth delegate callback already lands on the main queue — isolating this
/// class to `@MainActor` (matching `RodViewModel`) makes that guarantee explicit and lets
/// `send(_:)`'s mutable send-queue state be touched from both delegate callbacks and direct
/// calls without a separate lock.
@MainActor
final class TransportClient: NSObject, TransportProtocol {

    enum ClientError: Error {
        case notConnected
        case encodingFailed
        case notReady
    }

    private struct QueuedSend {
        var remainingChunks: [Data]
        let continuation: CheckedContinuation<Void, Error>
    }

    private let serviceUUID = CBUUID(string: SessionConfiguration.bleServiceUUID)
    private let stateUUID = CBUUID(string: SessionConfiguration.bleStateCharacteristicUUID)
    private let reliableOutUUID = CBUUID(string: SessionConfiguration.bleReliableOutCharacteristicUUID)
    private let commandUUID = CBUUID(string: SessionConfiguration.bleCommandCharacteristicUUID)

    private var peripheralManager: CBPeripheralManager!
    private var stateCharacteristic: CBMutableCharacteristic?
    private var reliableOutCharacteristic: CBMutableCharacteristic?
    private var commandCharacteristic: CBMutableCharacteristic?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let inboundReassembler = BLEMessageReassembler()

    private var subscribedCentral: CBCentral?
    private var wantsToAdvertise = false
    private var isServiceAdded = false
    private var reliableSendQueue: [QueuedSend] = []
    private let pairedCentralStore = PairedCentralStore()

    var isConnected: Bool { subscribedCentral != nil }

    /// The World this peripheral is paired with, if a central has ever subscribed — `nil` means
    /// "not paired yet, will pair with the next central that subscribes." `CBCentral` exposes no
    /// display name (unlike `CBPeripheral` on World's side), so only a short identifier is shown.
    var hasPairedDevice: Bool { pairedCentralStore.identifier != nil }
    var pairedDeviceShortID: String? {
        pairedCentralStore.identifier.map { String($0.uuidString.prefix(8)) }
    }

    var onMessage: ((NetworkMessage) -> Void)?
    var onStateChange: ((ConnectionState) -> Void)?

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        #if DEBUG
        print("[CLIENT] Initialized (CoreBluetooth peripheral)")
        #endif
    }

    func connect() async throws {
        #if DEBUG
        print("[CLIENT] Start advertising")
        #endif
        wantsToAdvertise = true
        onStateChange?(.searching)
        startAdvertisingIfPossible()
    }

    func disconnect() {
        wantsToAdvertise = false
        peripheralManager.stopAdvertising()
        failAllQueuedSends(with: ClientError.notConnected)
        subscribedCentral = nil
        inboundReassembler.reset()
        onStateChange?(.disconnected)
    }

    /// Clears the saved pairing (see `PairedCentralStore`) so the next central to subscribe pairs
    /// fresh — the same first-run behavior as before any pairing existed. Advertising keeps
    /// running (never stopped here), matching the existing reconnect behavior in
    /// `didUnsubscribeFrom`, so a new Mac can pair immediately without restarting the app.
    func forgetPairedDevice() {
        pairedCentralStore.clear()
        failAllQueuedSends(with: ClientError.notConnected)
        subscribedCentral = nil
        inboundReassembler.reset()
        onStateChange?(.disconnected)
    }

    func send(_ message: NetworkMessage) async throws {
        guard isConnected else { throw ClientError.notConnected }
        guard let data = try? encoder.encode(message) else { throw ClientError.encodingFailed }

        switch message {
        case .state:
            sendUnreliable(data)
        case .discoveryToken, .fishingEvent, .hookPhase, .tutorialState, .caughtSpecies:
            try await sendReliable(data)
        }
    }

    // MARK: - GATT setup

    private func setUpServiceIfNeeded() {
        guard !isServiceAdded else { return }

        let state = CBMutableCharacteristic(type: stateUUID, properties: [.notify], value: nil, permissions: [])
        let reliableOut = CBMutableCharacteristic(type: reliableOutUUID, properties: [.indicate], value: nil, permissions: [])
        let command = CBMutableCharacteristic(type: commandUUID, properties: [.write], value: nil, permissions: [.writeable])
        stateCharacteristic = state
        reliableOutCharacteristic = reliableOut
        commandCharacteristic = command

        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [state, reliableOut, command]
        peripheralManager.add(service)
    }

    private func startAdvertisingIfPossible() {
        guard wantsToAdvertise, isServiceAdded, peripheralManager.state == .poweredOn else { return }
        guard !peripheralManager.isAdvertising else { return }
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "Rod"
        ])
    }

    // MARK: - Sending

    /// Bytes available per packet for the currently subscribed central — `BLEFraming` accounts
    /// for its own header within this budget.
    private func chunkBudget() -> Int {
        guard let central = subscribedCentral else { return 20 }
        return max(BLEFraming.headerSize + 1, central.maximumUpdateValueLength)
    }

    /// Restricts every notify/indicate send to the paired central specifically (`nil` would mean
    /// "every subscribed central," which would leak state/events to an unpaired Mac that happened
    /// to subscribe even though the app never treats it as connected — see `didSubscribeTo`).
    private var sendTargets: [CBCentral]? {
        subscribedCentral.map { [$0] }
    }

    /// Never fragments: a `.state` sample that doesn't fit in one packet is dropped outright
    /// rather than risking a desynced multi-chunk stream on a channel with no delivery
    /// guarantee — see `SessionConfiguration.bleStateCharacteristicUUID`'s doc comment. A fresher
    /// sample is always ~33 ms away, so silently dropping one oversized sample is the same
    /// semantics `NetworkMessage.requiresReliableDelivery` already documents for this path. This
    /// used to fail with zero signal (ADR-063: `RodState.CodingKeys` exists specifically to keep
    /// a populated-`castSolution` payload safely under one chunk) — logged now so a future field
    /// addition that creeps back over budget shows up immediately instead of silently dropping
    /// every affected message.
    private func sendUnreliable(_ data: Data) {
        guard let stateCharacteristic else { return }
        let framed = BLEFraming.chunks(for: data, maxChunkSize: chunkBudget())
        guard framed.count == 1 else {
            #if DEBUG
            print("[CLIENT] .state dropped: \(data.count) bytes exceeds one-chunk budget of \(chunkBudget())")
            #endif
            return
        }
        let sent = peripheralManager.updateValue(framed[0], for: stateCharacteristic, onSubscribedCentrals: sendTargets)
        #if DEBUG
        if !sent {
            print("[CLIENT] .state updateValue returned false (send queue full), \(data.count) bytes")
        }
        #endif
    }

    /// Fragments if needed and queues behind any send already in flight, so overlapping calls
    /// (e.g. two `.fishingEvent`s sent close together) don't clobber each other's chunk lists —
    /// each waits its turn via CoreBluetooth's own indicate backpressure
    /// (`updateValue` returning `false` until `peripheralManagerIsReady` fires).
    private func sendReliable(_ data: Data) async throws {
        let chunks = BLEFraming.chunks(for: data, maxChunkSize: chunkBudget())
        try await withCheckedThrowingContinuation { continuation in
            reliableSendQueue.append(QueuedSend(remainingChunks: chunks, continuation: continuation))
            if reliableSendQueue.count == 1 {
                drainReliableQueue()
            }
        }
    }

    private func drainReliableQueue() {
        guard let reliableOutCharacteristic else {
            failAllQueuedSends(with: ClientError.notReady)
            return
        }

        while var current = reliableSendQueue.first {
            while !current.remainingChunks.isEmpty {
                let next = current.remainingChunks[0]
                let sent = peripheralManager.updateValue(next, for: reliableOutCharacteristic, onSubscribedCentrals: sendTargets)
                guard sent else {
                    reliableSendQueue[0] = current
                    return
                }
                current.remainingChunks.removeFirst()
            }
            reliableSendQueue.removeFirst()
            current.continuation.resume()
        }
    }

    private func failAllQueuedSends(with error: Error) {
        let queued = reliableSendQueue
        reliableSendQueue.removeAll()
        for item in queued {
            item.continuation.resume(throwing: error)
        }
    }
}

// `@preconcurrency`: `CBPeripheralManagerDelegate` (Objective-C, unisolated) is called by
// CoreBluetooth on the queue passed to `CBPeripheralManager(delegate:queue:)` — `nil` here means
// the main queue, matching this class's own `@MainActor` isolation in practice even though the
// protocol itself carries no such guarantee statically. This is the standard bridge for
// implementing an unisolated ObjC delegate protocol from an actor-isolated Swift type.
extension TransportClient: @preconcurrency CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        #if DEBUG
        print("[CLIENT] Bluetooth state -> \(peripheral.state.rawValue)")
        #endif
        switch peripheral.state {
        case .poweredOn:
            setUpServiceIfNeeded()
            startAdvertisingIfPossible()
        case .poweredOff, .unauthorized, .unsupported:
            onStateChange?(.failed)
        default:
            break
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            #if DEBUG
            print("========== ADD SERVICE FAILED ==========")
            print(error!)
            #endif
            onStateChange?(.failed)
            return
        }
        isServiceAdded = true
        startAdvertisingIfPossible()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        guard let error else { return }
        #if DEBUG
        print("========== ADVERTISING FAILED ==========")
        print(error)
        #endif
        onStateChange?(.failed)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        guard characteristic.uuid == stateUUID else { return }
        // Once a device is paired, ignore any other central subscribing — several Rods/Worlds can
        // be in range of each other in the same room. The central is still subscribed at the BLE
        // protocol level (harmless; CoreBluetooth has no "reject a subscription" API), but
        // `subscribedCentral` never becomes it, so `isConnected`/`sendTargets` both stay pointed
        // at the paired central only and this Mac never receives state/events.
        if let pairedID = pairedCentralStore.identifier, central.identifier != pairedID {
            #if DEBUG
            print("[CLIENT] Ignoring unpaired central: \(central.identifier)")
            #endif
            return
        }
        #if DEBUG
        print("[CLIENT] Central subscribed: \(central.identifier)")
        #endif
        subscribedCentral = central
        if pairedCentralStore.identifier == nil {
            pairedCentralStore.save(identifier: central.identifier)
        }
        onStateChange?(.ready)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard characteristic.uuid == stateUUID, central.identifier == subscribedCentral?.identifier else { return }
        #if DEBUG
        print("[CLIENT] Central unsubscribed: \(central.identifier)")
        #endif
        failAllQueuedSends(with: ClientError.notConnected)
        subscribedCentral = nil
        inboundReassembler.reset()
        onStateChange?(.disconnected)
        // Advertising is left running (never stopped here) so a peer that comes back into range
        // reconnects automatically — matches the previous MPC behavior of leaving the
        // browser/advertiser active continuously after the initial `connect()` call.
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        drainReliableQueue()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard request.characteristic.uuid == commandUUID, let value = request.value else { continue }
            let messages = inboundReassembler.feed(value)
            for messageData in messages {
                do {
                    let message = try decoder.decode(NetworkMessage.self, from: messageData)
                    onMessage?(message)
                } catch {
                    // Was a silent `try?` — a schema mismatch (e.g. only one of Rod/World rebuilt
                    // after a `RodState`/`NetworkMessage` field change) previously dropped every
                    // message with zero signal, reading as "connected but nothing ever happens."
                    #if DEBUG
                    print("[CLIENT] Failed to decode incoming message (\(messageData.count) bytes): \(error)")
                    #endif
                }
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
