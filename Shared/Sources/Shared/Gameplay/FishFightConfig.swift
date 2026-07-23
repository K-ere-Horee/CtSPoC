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
    /// `pullRateResistanceMultiplier` below, not from this value. Cut 30% (0.15 -> 0.105) per
    /// direct request to ease "tension slacking" — `pullRateResistanceMultiplier` (tier
    /// differentiation) is untouched, matching this session's established pattern of scaling only
    /// the base term so easier tiers stay easier proportionally, not just uniformly.
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
    /// from `pullSpeedResistanceMultiplier`, not this floor. Halved 0.7 -> 0.35 (ADR-039 retune,
    /// "fish pull speed rasanya terlalu kencang"), then cut a further 25% -> **0.2625** ("kurangin
    /// keduanya by 25%") — since `fishPullSpeed` is `basePullSpeed * (1 + resistance *
    /// pullSpeedResistanceMultiplier)`, scaling only this term keeps the reduction uniform across
    /// every resistance/tier, without needing to also touch `pullSpeedResistanceMultiplier`. Raised
    /// 0.25 -> **0.375** (ADR-120, "multiply semua fish run speed by 1.5x") — since every species'
    /// `fishPullSpeed` shares this same floor term multiplicatively, scaling only this uniformly
    /// raises *every* species' run speed by exactly 1.5x while leaving `pullSpeedResistanceMultiplier`
    /// (ADR-119's per-species differentiation) untouched.
    public var basePullSpeed: Float
    /// How strongly `resistance` scales `fishPullSpeed` on top of `basePullSpeed`:
    /// `fishPullSpeed = basePullSpeed * (1 + resistance * pullSpeedResistanceMultiplier)`. Same
    /// role as `pullRateResistanceMultiplier` above, for the physical tug-of-war instead of
    /// tension.
    ///
    /// ADR-119: raised 1.8 -> 2.6 — reported directly, "masa speed lari marlin sama grouper sama?
    /// harusnya ada difficulty scale berdasarkan ukuran dan jenis ikan" (why is Marlin's running
    /// speed the same as Grouper's? there should be a difficulty scale based on the fish's size
    /// and species). At the old 1.8, a max-size-roll Grouper (`resistance` ceiling 0.25) and a
    /// max-size-roll Marlin (ceiling 0.80) produced `fishPullSpeed` of 0.36 vs 0.61 m/s — real but
    /// modest (~70% faster), easy to miss mid-fight since it only governs the *idle-drift* half of
    /// the tug-of-war (see `reelSpeedResistanceDrag` below for the other half, which had *zero*
    /// species dependency before this same pass). At 2.6 the same pair is 0.41 vs 0.80 m/s
    /// (~95% faster) — `basePullSpeed` (the `resistance == 0` floor every species shares) is
    /// deliberately left untouched, so the easiest fish still feels the same, only the top end of
    /// the scale stretches further.
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

    // MARK: Fight flick (ADR-089 — replaces ADR-078's timed QTE prompt, itself replacing the
    // ADR-053 lean-left/right juke)

    /// Instant `lineTension` relief applied every time the player flicks the rod forward while a
    /// fish is hooked — a one-time reward, not a per-second rate (unlike the base tug-of-war
    /// formula). Unlike the ADR-078 mechanic this replaces, every flick counts; there is no
    /// spawn timer/reaction window to wait for or miss.
    public var fightFlickRelief: Float
    /// Seconds right after a fish is hooked during which `handleFightFlick()` is suppressed
    /// (ADR-093) — the hook-set flick's own physical follow-through can otherwise register as one
    /// or more separate flicks a beat later, each immediately shaving `fightFlickRelief` off a
    /// `lineTension` that was just set to `initialTension`.
    public var fightFlickGraceDuration: Float

    // MARK: Bite window (ADR-088 — flick to set the hook, replaces the old instant auto-bite)

    /// Seconds the player has to flick the rod forward after a bite-alert haptic before this
    /// attempt counts as missed — same calibrated forward-flick gesture as a cast release/fight
    /// flick, not a new one to learn.
    public var biteWindowDuration: Float
    /// How many missed bite-alert attempts the fish tolerates before giving up and swimming off
    /// (searching resumes as if this fish never bit) — "kalo setelah 3x haptics gede, ga nge
    /// cast, otomatis hook nya hening lagi."
    public var maxBiteAttempts: Int
    /// Seconds before the next bite-alert attempt starts after a miss — a random duration in this
    /// range, same "randomizer" spirit as the initial interest/bite timers.
    public var biteRetryMinInterval: Float
    public var biteRetryMaxInterval: Float

    // MARK: Tension-scaled reel pull speed (risk/reward)

    /// `lineTension` at/below this counts as the "safe" zone for `FishFightController.
    /// reelPullSpeed`'s purposes — chosen to match `LineTensionView`'s own `safeHigh` (the shaded
    /// green band's upper edge), though the two aren't code-shared, just numerically aligned so
    /// the reward curve feels consistent with what the tension bar visibly shows. At/below this,
    /// `reelPullSpeed` is always `reelPullSpeedSafe`.
    public var reelSpeedSafeTension: Float
    /// `lineTension` at/above this counts as the "danger" zone — matches `LineTensionView`'s own
    /// `dangerHigh` (the near-snap red edge). At/above this, `reelPullSpeed` is always
    /// `reelPullSpeedDanger`; between `reelSpeedSafeTension` and this it interpolates linearly.
    public var reelSpeedDangerTension: Float
    /// m/s per full (1.0) `RodState.reelSpeed` input while `lineTension` is in the safe zone.
    /// Launched at `0.5`, way too small — reported directly as "fish reel speed nya kekecilan,
    /// the gameplay is not even playable now" — corrected to `3.375` (matching the flat constant
    /// this risk/reward curve replaced), then explicitly retuned to **`2.0`** per direct request
    /// ("coba base nya 2 m/s instead of 0.5 - 1").
    public var reelPullSpeedSafe: Float
    /// m/s per full `RodState.reelSpeed` input once `lineTension` reaches the danger zone — the
    /// risk/reward payoff for holding tension near the snap edge instead of backing off to safety
    /// ("jadi ada reward untuk player yang berani stay di red zone"). Deliberately faster than
    /// `reelPullSpeedSafe` — explicitly retuned to **`4.0`** alongside `reelPullSpeedSafe`'s own
    /// move to `2.0` ("dari 2 m/s di area green, naik jadi 4 m/s di area merah"), keeping the same
    /// 2x ratio between the two.
    public var reelPullSpeedDanger: Float
    /// ADR-119: how much `resistance` (species x rolled size, same driver as `fishPullSpeed`/
    /// `effectiveFishPullRate`) drags down reel-in speed — `reelPullSpeed *= max
    /// (minimumReelSpeedFactor, 1 - resistance * reelSpeedResistanceDrag)`. Added because
    /// `reelPullSpeed` previously had *zero* species dependency (purely a function of
    /// `lineTension`), so a Grouper and a Marlin reeled in at the identical rate — only the
    /// passive/idle-drift side of the tug-of-war (`fishPullSpeed`) scaled with difficulty, which is
    /// half the reason "speed lari marlin sama grouper sama" was reported: the side of the fight
    /// the player actually spends most of their input on (reeling) didn't scale at all.
    public var reelSpeedResistanceDrag: Float
    /// Hard floor on the drag above, so a maxed-out `resistance` (the boss) can slow reeling but
    /// never make it feel broken/impossible — reeling a Scott-tier fish is still meaningfully
    /// possible, just visibly harder than a Grouper.
    public var minimumReelSpeedFactor: Float

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
        basePullSpeed: Float = 0.375,
        pullSpeedResistanceMultiplier: Float = 2.6,
        escapeDistanceAllowance: Float = 6.0,
        escapeAllowanceResistancePenalty: Float = 3.5,
        minEscapeDistanceAllowance: Float = 2.0,
        fightFlickRelief: Float = 0.15,
        fightFlickGraceDuration: Float = 1.0,
        biteWindowDuration: Float = 1.5,
        maxBiteAttempts: Int = 3,
        biteRetryMinInterval: Float = 0.8,
        biteRetryMaxInterval: Float = 1.6,
        reelSpeedSafeTension: Float = 0.7,
        reelSpeedDangerTension: Float = 0.85,
        reelPullSpeedSafe: Float = 2.0,
        reelPullSpeedDanger: Float = 4.0,
        reelSpeedResistanceDrag: Float = 0.45,
        minimumReelSpeedFactor: Float = 0.5,
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
        self.fightFlickRelief = fightFlickRelief
        self.fightFlickGraceDuration = fightFlickGraceDuration
        self.biteWindowDuration = biteWindowDuration
        self.maxBiteAttempts = maxBiteAttempts
        self.biteRetryMinInterval = biteRetryMinInterval
        self.biteRetryMaxInterval = biteRetryMaxInterval
        self.reelSpeedSafeTension = reelSpeedSafeTension
        self.reelSpeedDangerTension = reelSpeedDangerTension
        self.reelPullSpeedSafe = reelPullSpeedSafe
        self.reelPullSpeedDanger = reelPullSpeedDanger
        self.reelSpeedResistanceDrag = reelSpeedResistanceDrag
        self.minimumReelSpeedFactor = minimumReelSpeedFactor
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
