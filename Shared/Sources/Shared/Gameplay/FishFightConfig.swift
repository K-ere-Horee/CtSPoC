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
    /// Tension/sec drained by the fish pulling away while not countered. This is the *floor* of
    /// `effectiveFishPullRate`, shared by every species at `resistance == 0` (e.g. the smallest
    /// possible roll of any tier) — species/tier difficulty comes entirely from
    /// `pullRateResistanceMultiplier` below, not from this value.
    public var baseFishPullRate: Float
    /// Tension/sec gained per unit `reelSpeed` (0...1) while actively reeling. This is the
    /// single biggest lever on *overall* fight difficulty (every species scales against it) — at
    /// full reel speed, net tension rise is `baseReelTensionRate - effectiveFishPullRate` per
    /// second.
    public var baseReelTensionRate: Float
    /// How strongly a catch's rolled `resistance` (0...1, from `FishSpecies.resistance *
    /// sizeRatio` — ADR-030) scales `effectiveFishPullRate` on top of `baseFishPullRate`:
    /// `effectiveFishPullRate = baseFishPullRate * (1 + resistance * pullRateResistanceMultiplier)`.
    /// This is the knob that actually differentiates tiers — with the old implicit multiplier of
    /// 1.0, `resistance`'s contribution was smaller than `baseFishPullRate` itself, so `fish_a`
    /// through `scott` all produced a similar net tension rate and the tier jump was barely felt
    /// ("tingkat loncatan dari fish A - B - C - Scott masih kerasa gaada bedanya"). At `3.0`, a
    /// max-size-roll Scott can push net tension rate at full reel speed to roughly zero or
    /// negative — full-speed reeling alone stops being enough, forcing real tension management —
    /// while a max-size `fish_a` stays comfortably winnable.
    public var pullRateResistanceMultiplier: Float

    // MARK: Tug-of-war and distance escape

    /// m/s the hooked fish pulls the hook away from the rod at `resistance == 0` — both while the
    /// player isn't reeling (drift) and, subtracted from the player's reel speed, while they are
    /// (so a strong fish can still gain line against weak reeling). Species/tier difficulty comes
    /// from `pullSpeedResistanceMultiplier`, not this floor.
    public var basePullSpeed: Float
    /// How strongly `resistance` scales `fishPullSpeed` on top of `basePullSpeed`:
    /// `fishPullSpeed = basePullSpeed * (1 + resistance * pullSpeedResistanceMultiplier)`. Same
    /// role as `pullRateResistanceMultiplier` above, for the physical tug-of-war instead of
    /// tension.
    public var pullSpeedResistanceMultiplier: Float
    /// Extra line (meters beyond the fight's starting hook-to-rod distance) a fish may take
    /// before the fight resolves as escaped outright — the "spooled" failure, independent of
    /// `lineTension`. This is the value at `resistance == 0`; see
    /// `escapeAllowanceResistancePenalty` for how tougher fish tighten it.
    public var escapeDistanceAllowance: Float
    /// Meters subtracted from `escapeDistanceAllowance` per unit `resistance` — a tougher fish
    /// gives less rope before a run counts as spooled:
    /// `effectiveAllowance = max(minEscapeDistanceAllowance, escapeDistanceAllowance - resistance
    /// * escapeAllowanceResistancePenalty)`.
    public var escapeAllowanceResistancePenalty: Float
    /// Hard floor on the resistance-adjusted allowance above, so a maxed-out `resistance` can
    /// never shrink it to an unfair sliver.
    public var minEscapeDistanceAllowance: Float

    // MARK: Fight direction (lateral juke)

    /// A hooked fish's left/right juking phase lasts a random duration in this range (seconds),
    /// starting the instant it bites — not the whole fight, just this sub-mechanic. After it
    /// elapses, `FishFightController.fightDirection` goes back to `nil` and only the base
    /// tension/tug-of-war fight (above) continues for however much longer the fight naturally
    /// takes.
    public var fightDirectionMinDuration: Float
    public var fightDirectionMaxDuration: Float
    /// While the juking phase is active, the fish's pull direction flips after a random interval
    /// in this range (seconds) — "rapid randomizer": short enough that the player has to keep
    /// reacting, not a single slow left-then-right swing.
    public var fightDirectionSwitchMinInterval: Float
    public var fightDirectionSwitchMaxInterval: Float
    /// Minimum `abs(RodState.roll)` (radians, relative to the calibrated idle pose) for the
    /// player's current rod tilt to count as actively countering a direction at all — below this,
    /// the rod reads as roughly upright/neutral, not a deliberate counter-lean either way.
    public var fightDirectionRollThreshold: Double
    /// Tension/sec *relief* applied on top of the base fight formula while the player is actively
    /// countering the fish's current pull direction correctly (rod rolled opposite the fish's
    /// pull, past `fightDirectionRollThreshold`) — rewards reading the fish's juke and leaning the
    /// rod the other way, real-fishing "rod-side pressure" style.
    public var fightDirectionCounterRelief: Float
    /// Tension/sec *penalty* applied on top of the base fight formula whenever the player isn't
    /// countering correctly (rod neutral, or rolled the wrong way) while the juking phase is
    /// active — punishes ignoring the fish's direction, not just its raw pull strength.
    public var fightDirectionPenalty: Float

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
        baseReelTensionRate: Float = 0.6,
        pullRateResistanceMultiplier: Float = 3.0,
        basePullSpeed: Float = 0.7,
        pullSpeedResistanceMultiplier: Float = 1.8,
        escapeDistanceAllowance: Float = 6.0,
        escapeAllowanceResistancePenalty: Float = 3.5,
        minEscapeDistanceAllowance: Float = 2.0,
        fightDirectionMinDuration: Float = 5.0,
        fightDirectionMaxDuration: Float = 10.0,
        fightDirectionSwitchMinInterval: Float = 0.6,
        fightDirectionSwitchMaxInterval: Float = 1.8,
        fightDirectionRollThreshold: Double = 0.15,
        fightDirectionCounterRelief: Float = 0.25,
        fightDirectionPenalty: Float = 0.20,
        tensionBandMediumThreshold: Float = 0.55,
        tensionBandHighThreshold: Float = 0.8,
        lowBandInterval: TimeInterval = 0.5,
        mediumBandInterval: TimeInterval = 0.28,
        highBandInterval: TimeInterval = 0.11,
        lowBandIntensity: Float = 1.0,
        mediumBandIntensity: Float = 1.0,
        highBandIntensity: Float = 1.0,
        lowBandSharpness: Float = 0.4,
        mediumBandSharpness: Float = 0.55,
        highBandSharpness: Float = 0.75
    ) {
        self.initialTension = initialTension
        self.baseFishPullRate = baseFishPullRate
        self.baseReelTensionRate = baseReelTensionRate
        self.pullRateResistanceMultiplier = pullRateResistanceMultiplier
        self.basePullSpeed = basePullSpeed
        self.pullSpeedResistanceMultiplier = pullSpeedResistanceMultiplier
        self.escapeDistanceAllowance = escapeDistanceAllowance
        self.escapeAllowanceResistancePenalty = escapeAllowanceResistancePenalty
        self.minEscapeDistanceAllowance = minEscapeDistanceAllowance
        self.fightDirectionMinDuration = fightDirectionMinDuration
        self.fightDirectionMaxDuration = fightDirectionMaxDuration
        self.fightDirectionSwitchMinInterval = fightDirectionSwitchMinInterval
        self.fightDirectionSwitchMaxInterval = fightDirectionSwitchMaxInterval
        self.fightDirectionRollThreshold = fightDirectionRollThreshold
        self.fightDirectionCounterRelief = fightDirectionCounterRelief
        self.fightDirectionPenalty = fightDirectionPenalty
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
