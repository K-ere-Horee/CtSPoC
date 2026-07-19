//
//  FishingEvent.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 15/07/26.
//

import Foundation

/// Gameplay outcomes that may be reflected by controller feedback.
public enum FishingEvent: String, Codable, Sendable, Equatable {
    case cast
    case hookSplash
    case reelTick
    /// A fish is nearby and interested, but has not bitten yet. Rod starts
    /// a slow periodic haptic pulse until the next fishing event arrives.
    case fishInterested
    case fishBite
    case fishEscaped
    case catchFish
    case lineBreak
    /// Line-tension band transitions during a fight (ADR-039). World sends one when
    /// `FishFightController`'s tension crosses a band boundary; Rod then pulses continuously at
    /// that band's rhythm (spaced / regular / rapid taps, per `GAMEPLAY_ARCHITECTURE_V1.md`'s
    /// resistance-through-rhythm spec) until the next band event or any fight-ending event.
    case reelTensionLow
    case reelTensionMedium
    case reelTensionHigh
}
