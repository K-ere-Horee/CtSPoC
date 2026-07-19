//
//  FishFightConfig.swift
//  Shared
//

import Foundation

/// Every tunable number behind the fish fight — line tension, the distance escape, and Rod's
/// tension-band haptic rhythm — collected in one place instead of scattered as private
/// constants across `FishFightController` (World) and `FishingHaptics` (Rod). Both read the same
/// `FishFightConfig` instance so gameplay difficulty and haptic feel never drift apart from each
/// other. See ADR-039/ADR-040 in `ARCHITECTURE_DECISIONS.md` for the reasoning behind each
/// default, and retune directly here — every field is a `var`, this is meant to be hand-edited.
public struct FishFightConfig: Codable, Sendable, Equatable {

    // MARK: Line tension

    /// `lineTension` a bite starts at (0...1) — not 0, so the player has room to react in both
    /// directions before either failure edge.
    public var initialTension: Float
    /// Tension/sec drained by the fish pulling away while not countered.
    public var baseFishPullRate: Float
    /// Tension/sec gained per unit `reelSpeed` (0...1) while actively reeling. This is the
    /// single biggest lever on fight difficulty: at full reel speed, net tension rise is
    /// `baseReelTensionRate - effectiveFishPullRate` per second, and `effectiveFishPullRate` for
    /// a weak species/roll can be as low as ~0.15 — so this value alone decides whether a gentle
    /// species is winnable or an instant overshoot.
    public var baseReelTensionRate: Float

    // MARK: Tug-of-war and distance escape

    /// m/s the hooked fish pulls the hook away from the rod — both while the player isn't
    /// reeling (drift) and, subtracted from the player's reel speed, while they are (so a strong
    /// fish can still gain line against weak reeling).
    public var basePullSpeed: Float
    /// Extra line (meters beyond the fight's starting hook-to-rod distance) a fish may take
    /// before the fight resolves as escaped outright — the "spooled" failure, independent of
    /// `lineTension`.
    public var escapeDistanceAllowance: Float

    // MARK: Tension bands (Rod haptic rhythm)

    /// `lineTension` at/above this is "medium" band; below is "low". Below `dangerLow`-style
    /// thresholds aren't tracked here — bands are a haptic-feel signal, not a failure boundary.
    public var tensionBandMediumThreshold: Float
    /// `lineTension` at/above this is "high" band.
    public var tensionBandHighThreshold: Float

    /// Seconds between Rod haptic taps at each band — lower is more "continuous."
    public var lowBandInterval: TimeInterval
    public var mediumBandInterval: TimeInterval
    public var highBandInterval: TimeInterval
    /// 0...1 per band, passed straight to `CHHapticEventParameter.hapticIntensity`.
    public var lowBandIntensity: Float
    public var mediumBandIntensity: Float
    public var highBandIntensity: Float
    /// 0...1 per band, passed straight to `CHHapticEventParameter.hapticSharpness`.
    public var lowBandSharpness: Float
    public var mediumBandSharpness: Float
    public var highBandSharpness: Float

    public init(
        initialTension: Float = 0.5,
        baseFishPullRate: Float = 0.15,
        baseReelTensionRate: Float = 0.55,
        basePullSpeed: Float = 0.8,
        escapeDistanceAllowance: Float = 6.0,
        tensionBandMediumThreshold: Float = 0.55,
        tensionBandHighThreshold: Float = 0.8,
        lowBandInterval: TimeInterval = 0.5,
        mediumBandInterval: TimeInterval = 0.28,
        highBandInterval: TimeInterval = 0.11,
        lowBandIntensity: Float = 0.3,
        mediumBandIntensity: Float = 0.45,
        highBandIntensity: Float = 0.7,
        lowBandSharpness: Float = 0.3,
        mediumBandSharpness: Float = 0.45,
        highBandSharpness: Float = 0.6
    ) {
        self.initialTension = initialTension
        self.baseFishPullRate = baseFishPullRate
        self.baseReelTensionRate = baseReelTensionRate
        self.basePullSpeed = basePullSpeed
        self.escapeDistanceAllowance = escapeDistanceAllowance
        self.tensionBandMediumThreshold = tensionBandMediumThreshold
        self.tensionBandHighThreshold = tensionBandHighThreshold
        self.lowBandInterval = lowBandInterval
        self.mediumBandInterval = mediumBandInterval
        self.highBandInterval = highBandInterval
        self.lowBandIntensity = lowBandIntensity
        self.mediumBandIntensity = mediumBandIntensity
        self.highBandIntensity = highBandIntensity
        self.lowBandSharpness = lowBandSharpness
        self.mediumBandSharpness = mediumBandSharpness
        self.highBandSharpness = highBandSharpness
    }
}
