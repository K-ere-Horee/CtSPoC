//
//  NetworkMessage.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation

public enum NetworkMessage: Codable, Sendable {

    case state(RodState)
    case discoveryToken(Data)
    case fishingEvent(FishingEvent)
    case hookPhase(HookPhase)
    /// Full set of species IDs (`FishSpecies.id`) the player has ever caught, per World's own
    /// `FishRecordStore` (ADR-110/111) — sent so Rod's standalone AR fish-preview screen can list
    /// only species actually caught, since Rod has no direct access to World's local record.
    /// Always the *complete* set, not a delta — simplest thing that can't drift out of sync from
    /// a dropped incremental update, and cheap enough (a handful of short string IDs) that the
    /// resend cost is negligible.
    case caughtSpecies(Set<String>)

    /// Continuous, high-frequency telemetry (`state`, streamed on every motion sample) should use
    /// unreliable/unordered transport delivery: a stale orientation sample is worthless once a
    /// newer one exists, so retransmitting a dropped one only adds head-of-line-blocking latency
    /// for every real sample queued behind it — the classic cause of a MultipeerConnectivity
    /// control stream feeling laggy under any packet loss or congestion. Discrete, one-shot events
    /// (connection/gameplay signals that must not be silently dropped) stay reliable.
    public var requiresReliableDelivery: Bool {
        switch self {
        case .state:
            return false
        case .discoveryToken, .fishingEvent, .hookPhase, .caughtSpecies:
            return true
        }
    }
}
