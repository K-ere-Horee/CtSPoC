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
    /// ADR-117: World -> Rod, sent whenever the tutorial's visibility or step changes, so Rod knows
    /// when to show its own "Next"/"Skip Tutorial" buttons rather than the tutorial living only as
    /// a World-side tap-to-advance overlay with no dedicated controls.
    case tutorialState(isActive: Bool, stepIndex: Int, stepCount: Int)

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
        case .discoveryToken, .fishingEvent, .hookPhase, .tutorialState:
            return true
        }
    }
}
