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
    /// The player flicked the rod forward while a fish is hooked (Rod -> World, ADR-089 —
    /// replacing ADR-078's timed QTE prompt/reaction-window mechanic, which required waiting for
    /// a spawned prompt and could be missed with no visible cause; every flick during a fight is
    /// now always meaningful). Reused directly from the calibrated cast-release gesture;
    /// `FishFightController.handleFightFlick()` is a no-op outside a fight entirely.
    case fightFlick
    /// A bite-alert window just opened during `.hookInWater` (ADR-088, replacing the old instant
    /// auto-bite) — World -> Rod, a strong haptic telling the player a fish is testing the bait
    /// *right now* and to flick the rod forward (same gesture as a cast release/fight flick)
    /// within `FishFightConfig.biteWindowDuration` to actually set the hook.
    case biteAlert
    /// The player flicked the rod forward during an active bite window (Rod -> World, alongside
    /// `fightFlick` the only other case Rod itself constructs and sends). Reused from the same
    /// calibrated forward-flick gesture; `FishFightController.handleHookSetFlick()` only reacts to
    /// it while a bite window is actually open, so a stray/late flick is a no-op.
    case hookSet
    /// The fish lost interest after `FishFightConfig.maxBiteAttempts` missed bite windows and swam
    /// off without ever being hooked (ADR-088) — World -> Rod, a soft/deflating cue distinct from
    /// `fishEscaped` (which means a fish *was* hooked and got away mid-fight; this one never got
    /// that far). Searching resumes as if this fish never bit.
    case fishGaveUp
}
