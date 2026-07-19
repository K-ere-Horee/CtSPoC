//
//  TransportHost.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import CoreBluetooth
import Foundation
import Shared

/// World is the BLE **central**: it scans for Rod's advertised GATT service, connects, subscribes
/// to Rod's state/event characteristics, and writes commands back — mirroring the previous
/// MultipeerConnectivity "host" role (the side that reacts to whichever peer shows up).
///
/// `@MainActor` for the same reason as Rod's `TransportClient`: the central manager is
/// constructed with `queue: nil` (main queue), so isolating this class to `@MainActor` (matching
/// `WorldViewModel`) makes that guarantee explicit and lets `send(_:)`'s mutable send-queue state
/// be touched from both delegate callbacks and direct calls without a separate lock.
@MainActor
final class TransportHost: NSObject, TransportProtocol {

    enum HostError: Error {
        case noConnectedPeripheral
        case encodingFailed
        case missingCharacteristic
    }

    private struct QueuedSend {
        var remainingChunks: [Data]
        let continuation: CheckedContinuation<Void, Error>
    }

    private let serviceUUID = CBUUID(string: SessionConfiguration.bleServiceUUID)
    private let stateUUID = CBUUID(string: SessionConfiguration.bleStateCharacteristicUUID)
    private let reliableOutUUID = CBUUID(string: SessionConfiguration.bleReliableOutCharacteristicUUID)
    private let commandUUID = CBUUID(string: SessionConfiguration.bleCommandCharacteristicUUID)

    private var centralManager: CBCentralManager!
    private var rodPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let stateReassembler = BLEMessageReassembler()
    private let reliableInReassembler = BLEMessageReassembler()

    private var wantsToScan = false
    private var isStateSubscribed = false
    private var isReliableInSubscribed = false
    private var commandSendQueue: [QueuedSend] = []

    var isConnected: Bool { commandCharacteristic != nil }

    var onMessage: ((NetworkMessage) -> Void)?
    var onStateChange: ((ConnectionState) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        #if DEBUG
        print("[HOST] Initialized (CoreBluetooth central)")
        #endif
    }

    func connect() async throws {
        #if DEBUG
        print("[HOST] Start scanning")
        #endif
        wantsToScan = true
        onStateChange?(.searching)
        startScanningIfPossible()
    }

    func disconnect() {
        wantsToScan = false
        centralManager.stopScan()
        if let rodPeripheral {
            centralManager.cancelPeripheralConnection(rodPeripheral)
        }
        tearDownConnection()
        onStateChange?(.disconnected)
    }

    func send(_ message: NetworkMessage) async throws {
        guard let rodPeripheral, let commandCharacteristic else {
            throw HostError.noConnectedPeripheral
        }
        guard let data = try? encoder.encode(message) else { throw HostError.encodingFailed }
        try await sendCommand(data, to: rodPeripheral, characteristic: commandCharacteristic)
    }

    // MARK: - Scanning / connection lifecycle

    private func startScanningIfPossible() {
        guard wantsToScan, centralManager.state == .poweredOn, rodPeripheral == nil else { return }
        centralManager.scanForPeripherals(withServices: [serviceUUID])
    }

    private func tearDownConnection() {
        failAllQueuedSends(with: HostError.noConnectedPeripheral)
        commandCharacteristic = nil
        rodPeripheral = nil
        isStateSubscribed = false
        isReliableInSubscribed = false
        stateReassembler.reset()
        reliableInReassembler.reset()
    }

    // MARK: - Sending

    private func chunkBudget(for peripheral: CBPeripheral) -> Int {
        max(BLEFraming.headerSize + 1, peripheral.maximumWriteValueLength(for: .withResponse))
    }

    /// Queues behind any send already in flight (writes complete one at a time, signaled by
    /// `peripheral(_:didWriteValueFor:error:)`), so overlapping calls don't interleave chunks
    /// from two different logical messages.
    private func sendCommand(_ data: Data, to peripheral: CBPeripheral, characteristic: CBCharacteristic) async throws {
        let chunks = BLEFraming.chunks(for: data, maxChunkSize: chunkBudget(for: peripheral))
        try await withCheckedThrowingContinuation { continuation in
            commandSendQueue.append(QueuedSend(remainingChunks: chunks, continuation: continuation))
            if commandSendQueue.count == 1 {
                drainCommandQueue()
            }
        }
    }

    /// Sends exactly one chunk of the head-of-queue message, then waits for
    /// `didWriteValueFor`/`error` to advance — unlike the peripheral side's notify/indicate
    /// (bulk-drainable via a boolean return), central writes only signal completion one at a
    /// time via that delegate callback.
    private func drainCommandQueue() {
        guard let rodPeripheral, let commandCharacteristic else {
            failAllQueuedSends(with: HostError.missingCharacteristic)
            return
        }
        guard !commandSendQueue.isEmpty else { return }

        if commandSendQueue[0].remainingChunks.isEmpty {
            let finished = commandSendQueue.removeFirst()
            finished.continuation.resume()
            drainCommandQueue()
            return
        }

        let next = commandSendQueue[0].remainingChunks[0]
        rodPeripheral.writeValue(next, for: commandCharacteristic, type: .withResponse)
    }

    private func failAllQueuedSends(with error: Error) {
        let queued = commandSendQueue
        commandSendQueue.removeAll()
        for item in queued {
            item.continuation.resume(throwing: error)
        }
    }
}

// `@preconcurrency`: see the matching note on `TransportClient`'s `CBPeripheralManagerDelegate`
// conformance — `CBCentralManager(delegate:queue:)` was constructed with `queue: nil` (main
// queue), matching this class's `@MainActor` isolation in practice.
extension TransportHost: @preconcurrency CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        #if DEBUG
        print("[HOST] Bluetooth state -> \(central.state.rawValue)")
        #endif
        switch central.state {
        case .poweredOn:
            startScanningIfPossible()
        case .poweredOff, .unauthorized, .unsupported:
            onStateChange?(.failed)
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard rodPeripheral == nil else { return }
        #if DEBUG
        print("[HOST] Discovered peripheral: \(peripheral.identifier)")
        #endif
        rodPeripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        onStateChange?(.connecting)
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        #if DEBUG
        print("[HOST] Connected: \(peripheral.identifier)")
        #endif
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        #if DEBUG
        print("========== CONNECT FAILED ==========")
        if let error { print(error) }
        #endif
        tearDownConnection()
        onStateChange?(.disconnected)
        startScanningIfPossible()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        #if DEBUG
        print("[HOST] Disconnected: \(peripheral.identifier)")
        #endif
        tearDownConnection()
        onStateChange?(.disconnected)
        // Scanning is restarted (never left permanently stopped here) so a peer that comes back
        // into range reconnects automatically — matches the previous MPC behavior of leaving the
        // browser/advertiser active continuously after the initial `connect()` call.
        startScanningIfPossible()
    }
}

// `@preconcurrency`: see the matching note on the `CBCentralManagerDelegate` conformance above —
// `CBPeripheral`'s delegate callbacks also land on the central manager's queue (main, here).
extension TransportHost: @preconcurrency CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            onStateChange?(.failed)
            return
        }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([stateUUID, reliableOutUUID, commandUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else {
            onStateChange?(.failed)
            return
        }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case stateUUID, reliableOutUUID:
                peripheral.setNotifyValue(true, for: characteristic)
            case commandUUID:
                commandCharacteristic = characteristic
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.isNotifying else { return }
        if characteristic.uuid == stateUUID { isStateSubscribed = true }
        if characteristic.uuid == reliableOutUUID { isReliableInSubscribed = true }
        if isStateSubscribed, isReliableInSubscribed, commandCharacteristic != nil {
            onStateChange?(.ready)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let value = characteristic.value else { return }

        let messages: [Data]
        switch characteristic.uuid {
        case stateUUID:
            messages = stateReassembler.feed(value)
        case reliableOutUUID:
            messages = reliableInReassembler.feed(value)
        default:
            return
        }

        for messageData in messages {
            guard let message = try? decoder.decode(NetworkMessage.self, from: messageData) else { continue }
            onMessage?(message)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == commandUUID, !commandSendQueue.isEmpty else { return }

        if let error {
            let failed = commandSendQueue.removeFirst()
            failed.continuation.resume(throwing: error)
            drainCommandQueue()
            return
        }

        commandSendQueue[0].remainingChunks.removeFirst()
        drainCommandQueue()
    }
}
