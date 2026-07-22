//
//  BLEFraming.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 17/07/26.
//

import Foundation

/// Splits an encoded message into BLE-packet-sized chunks, prefixed with a 4-byte big-endian
/// length header so a receiver (`BLEMessageReassembler`) can tell where one message ends and
/// the next begins even when a single message spans multiple packets. Pure `Data` manipulation
/// — no CoreBluetooth import, so this stays usable from both Rod and World's transport layers
/// without Shared taking on a platform dependency.
public enum BLEFraming {
    public static let headerSize = 4

    /// `maxChunkSize` is the raw bytes-per-packet budget (already accounting for whatever ATT
    /// overhead the caller has subtracted) — every chunk this returns, including the header on
    /// the first one, fits within it.
    public static func chunks(for payload: Data, maxChunkSize: Int) -> [Data] {
        precondition(maxChunkSize > headerSize, "maxChunkSize must exceed the framing header size")

        let length = UInt32(payload.count)
        var framed = Data([
            UInt8((length >> 24) & 0xFF),
            UInt8((length >> 16) & 0xFF),
            UInt8((length >> 8) & 0xFF),
            UInt8(length & 0xFF)
        ])
        framed.append(payload)

        var result: [Data] = []
        var offset = framed.startIndex
        while offset < framed.endIndex {
            let end = framed.index(offset, offsetBy: maxChunkSize, limitedBy: framed.endIndex) ?? framed.endIndex
            result.append(Data(framed[offset..<end]))
            offset = end
        }
        return result
    }
}

/// Accumulates raw chunks fed from successive BLE deliveries (notify/indicate/write callbacks)
/// and yields complete messages once enough bytes have arrived. One instance per inbound
/// characteristic — feeding chunks from two different logical streams into the same
/// reassembler would corrupt both.
public final class BLEMessageReassembler {
    private var buffer = Data()

    public init() {}

    /// Feed one raw received chunk. Returns every message that became complete as a result —
    /// normally 0 or 1, but could be more if multiple small messages arrived coalesced into a
    /// single delivery.
    @discardableResult
    public func feed(_ chunk: Data) -> [Data] {
        buffer.append(chunk)

        var messages: [Data] = []
        while buffer.count >= BLEFraming.headerSize {
            let header = [UInt8](buffer.prefix(BLEFraming.headerSize))
            let length = Int(header[0]) << 24 | Int(header[1]) << 16 | Int(header[2]) << 8 | Int(header[3])
            let totalNeeded = BLEFraming.headerSize + length
            guard buffer.count >= totalNeeded else { break }

            let message = Data(buffer.dropFirst(BLEFraming.headerSize).prefix(length))
            messages.append(message)
            buffer = Data(buffer.dropFirst(totalNeeded))
        }
        return messages
    }

    /// Discard any partial, never-to-be-completed message — call this on disconnect so a stale
    /// fragment from a previous connection can't corrupt the first message of the next one.
    public func reset() {
        buffer.removeAll()
    }
}
