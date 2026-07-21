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
    /// A flick-QTE prompt just spawned during a fight (ADR-078, replacing the ADR-053 lean-left/
    /// right juking mechanic) — World -> Rod, alerting the player to flick the rod forward (the
    /// same gesture as a cast release) within `FishFightConfig.qteReactionWindow`.
    case qtePrompt
    /// The player flicked the rod forward during a fight (Rod -> World, the only `FishingEvent`
    /// case Rod itself ever constructs and sends — every other case flows World -> Rod). Reused
    /// directly from the calibrated cast-release gesture; `FishFightController.handleQTEFlick()`
    /// only reacts to it while a QTE prompt is actually active, so a stray/late flick is a no-op.
    case qteFlick
}
