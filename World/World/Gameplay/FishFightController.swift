//
//  FishFightController.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 18/07/26.
//

import Shared
import Combine

/// Owns the search/interest/bite/fight/catch simulation and bookkeeping for
/// the single active fish. `WorldViewModel` drives it from `HookPhase`
/// transitions and reports the resolved outcome as a `FishingEvent`; this
/// controller has no knowledge of transport, hook entities, or RealityKit.
///
/// The fight is a single tension safe zone, matching
/// `GAMEPLAY_ARCHITECTURE_V1.md`: the fish continuously pulls the hook away
/// (draining tension) unless the player reels against it (raising tension).
/// Tension reaching 0 means the line went slack and the fish escaped;
/// reaching 1 means the player reeled too hard and the line snapped.
@MainActor
final class FishFightController: ObservableObject {

    enum FightFailure {
        case escaped
        case lineBreak
    }

    /// Which rhythm tier Rod's continuous fight haptics should play (ADR-039), derived from
    /// `lineTension`. `WorldViewModel` sends a `FishingEvent` whenever this changes mid-fight.
    enum TensionBand {
        case low
        case medium
        case high
    }

    /// What `updateSearching` just did this tick, if anything.
    enum SearchEvent {
        /// A fish became interested but hasn't bitten yet.
        case interested
        /// A bite window just opened (ADR-088) — the player must flick the rod forward within
        /// `FishFightConfig.biteWindowDuration` (`handleHookSetFlick()`) to actually hook the fish.
        /// `hasFishOnHook` is still `false` at this point.
        case biteAlert
        /// The fish gave up after `FishFightConfig.maxBiteAttempts` missed bite windows and swam
        /// off without ever being hooked; searching resumes as if it never bit.
        case gaveUp
    }

    @Published private(set) var hasFishOnHook = false
    /// A fish is nearby and interested but hasn't bitten. World may show a
    /// subtle cue; Rod plays a slow periodic haptic while this is `true`.
    @Published private(set) var isFishInterested = false
    /// Whether a bite-alert window is currently open (ADR-088) — the player has
    /// `biteWindowProgress` (ticking `1.0 -> 0.0`) seconds left to flick the rod forward
    /// (`handleHookSetFlick()`) before this attempt counts as missed. `hasFishOnHook` is still
    /// `false` while this is `true`.
    @Published private(set) var isBiteWindowActive = false
    /// `1.0` the instant a bite window opens, ticking down to `0.0` as `biteWindowDuration`
    /// elapses. Meaningless while `!isBiteWindowActive`.
    @Published private(set) var biteWindowProgress: Float = 0
    /// 0 (slack, fish escapes) ... 1 (snaps). Starts at `initialTension`
    /// when a fish bites, so the player has a buffer in both directions.
    @Published private(set) var lineTension: Float = 0
    @Published private(set) var caughtCount = 0
    @Published private(set) var lastCatchResult: FishCatchResult?
    /// Horizontal distance the most recent cast actually traveled before
    /// splashing, as measured by `WorldViewModel`. HUD-only; also drives
    /// `castZone`/`sizeRollWindow` below.
    @Published private(set) var lastCastDistance: Float = 0
    /// Current progression level (1...3), from `ProgressionStore`. See ADR-037.
    @Published private(set) var currentLevel: Int
    /// Set to a short message the instant a catch pushes `currentLevel` up (e.g. "Medium fish
    /// have entered the lake!"); the HUD shows it as a transient banner and calls
    /// `dismissLevelUpAnnouncement()` when done. `nil` otherwise.
    @Published private(set) var levelUpAnnouncement: String?

    /// Every tension/reel/escape/haptic-band number lives here now (ADR-039) — see
    /// `FishFightConfig`'s own doc comments for what each field does and why. Injectable so a
    /// future debug UI or save-file could override it; defaults to `FishFightConfig()`.
    private let config: FishFightConfig
    /// Rough max horizontal distance `WorldViewModel`'s projectile physics can produce at full
    /// charge (retuned for ADR-039's castSpeed 3.6 -> 5.0; ~24 m ballistic max). Only used to
    /// normalize `castDistance` into a 0...1 ratio; retune if launch physics change. Not part of
    /// `FishFightConfig` — this is cast physics, not fight tuning.
    private let maxExpectedCastDistance: Float = 20.0
    /// Hook-to-rod distance (meters) a bite guarantees at minimum, so a
    /// player who was already reeling in before the bite landed (and thus
    /// already near the rod) still gets a real fight instead of an instant
    /// catch. `WorldViewModel` applies this to the hook entity; this
    /// controller has no entity/position knowledge itself.
    let minimumFightDistance: Float = 0.4

    private var interestTimer = Float.random(in: 0.8...2.0)
    private var biteTimer: Float = 0
    /// Seconds left in the current bite window — counts down in `updateSearching` whenever
    /// `isBiteWindowActive`. Reaching 0 resolves this attempt as a miss.
    private var biteWindowTimer: Float = 0
    /// How many bite windows this fish has already missed (0...`maxBiteAttempts`). Resets to 0
    /// whenever a fish is newly hooked or gives up.
    private var biteAttemptsUsed = 0
    /// Seconds left before `handleFightFlick()` will accept another flick (ADR-093) — set to
    /// `config.fightFlickGraceDuration` the instant a fish is hooked, counts down in
    /// `updateFight`. Suppresses the hook-set flick's own physical follow-through from
    /// immediately registering as a separate fight-flick and shaving tension off a value that was
    /// just set.
    private var fightFlickGraceTimer: Float = 0
    private var currentSpecies: FishSpecies?
    private var currentWeight: Double = 0
    private var currentLength: Double = 0
    private var currentCastDistance: Float = 0
    /// Hook-to-rod distance on the first `updateFight` tick of the current fight — the baseline
    /// `escapeDistanceAllowance` is measured against. `nil` outside a fight.
    private var fightStartDistance: Float?
    private let recordStore: FishRecordStore
    private let progressionStore: ProgressionStore

    /// Passthrough to `recordStore`'s own set (ADR-111) — `WorldViewModel` has no other access to
    /// `recordStore`, which is private to this controller.
    var caughtSpeciesIDs: Set<String> {
        recordStore.caughtSpeciesIDs
    }

    init(
        recordStore: FishRecordStore = FishRecordStore(),
        progressionStore: ProgressionStore = ProgressionStore(),
        config: FishFightConfig = FishFightConfig()
    ) {
        self.recordStore = recordStore
        self.progressionStore = progressionStore
        self.config = config
        currentLevel = progressionStore.level
    }

    /// `(caught, needed)` toward the next tier unlock, or `nil` once every tier is unlocked —
    /// passthrough for the HUD, so it doesn't need its own reference to `ProgressionStore`.
    var progressTowardNextLevel: (caught: Int, needed: Int)? {
        progressionStore.progressTowardNextLevel
    }

    /// ADR-119: how many of `speciesID` have been caught so far — passthrough for the
    /// species-progress HUD, so it doesn't need its own reference to `FishRecordStore`.
    func catchCount(forSpeciesID speciesID: String) -> Int {
        recordStore.catchCount(for: speciesID)
    }

    /// Called by the HUD once it's shown `levelUpAnnouncement` for long enough.
    func dismissLevelUpAnnouncement() {
        levelUpAnnouncement = nil
    }

    /// Resets `ProgressionStore` back to Level 1 (only `.small` catchable), clears every species'
    /// catch count (ADR-119 — the species-progress checklist starts fresh alongside tier
    /// progression, not independently), and clears any in-flight level-up banner, so the player can
    /// replay the whole unlock progression from scratch — a debug/utility action, not part of the
    /// fishing session loop itself.
    func resetProgression() {
        progressionStore.reset()
        recordStore.resetCounts()
        currentLevel = progressionStore.level
        levelUpAnnouncement = nil
    }

    /// Call every tick a new cast lands in the water. `castDistance` is the
    /// horizontal distance that cast actually traveled, and gates how big a
    /// fish this cast can hook via `castZone`/`sizeRollWindow`.
    func resetForNewCast(castDistance: Float = 0) {
        hasFishOnHook = false
        isFishInterested = false
        isBiteWindowActive = false
        biteWindowProgress = 0
        biteWindowTimer = 0
        biteAttemptsUsed = 0
        fightFlickGraceTimer = 0
        currentSpecies = nil
        lineTension = 0
        interestTimer = Float.random(in: 0.8...2.0)
        currentCastDistance = castDistance
        lastCastDistance = castDistance
        fightStartDistance = nil
    }

    /// Call every tick while searching (`.hookInWater`). Returns the search
    /// event that just happened, if any: interest starting, or a bite.
    @discardableResult
    func updateSearching(deltaTime: Float) -> SearchEvent? {
        guard !hasFishOnHook else { return nil }

        if isBiteWindowActive {
            biteWindowTimer -= deltaTime
            biteWindowProgress = max(0, biteWindowTimer / config.biteWindowDuration)
            guard biteWindowTimer <= 0 else { return nil }

            // Missed this attempt — either try again or the fish gives up (ADR-088).
            isBiteWindowActive = false
            biteWindowProgress = 0
            biteAttemptsUsed += 1
            if biteAttemptsUsed >= config.maxBiteAttempts {
                isFishInterested = false
                biteAttemptsUsed = 0
                interestTimer = Float.random(in: 0.8...2.0)
                return .gaveUp
            }
            biteTimer = Float.random(in: config.biteRetryMinInterval...config.biteRetryMaxInterval)
            return nil
        }

        guard isFishInterested else {
            interestTimer -= deltaTime
            guard interestTimer <= 0 else { return nil }
            isFishInterested = true
            biteTimer = Float.random(in: 0.8...2.0)
            return .interested
        }

        biteTimer -= deltaTime
        guard biteTimer <= 0 else { return nil }

        // Open a bite window instead of hooking instantly (ADR-088) — the player must flick the
        // rod forward before `biteWindowTimer` runs out (`handleHookSetFlick()`) to actually set
        // the hook. `hasFishOnHook` stays `false` until then.
        isBiteWindowActive = true
        biteWindowTimer = config.biteWindowDuration
        biteWindowProgress = 1
        return .biteAlert
    }

    /// Call when Rod reports a forward flick while a bite window is open (ADR-088). Rolls and
    /// hooks the fish exactly as the old instant-auto-bite path used to, just gated behind the
    /// player's timed reaction instead of firing unconditionally. Returns whether it actually
    /// hooked a fish — `false` (a no-op) if no bite window is currently active, mirroring
    /// `handleFightFlick()`'s own "stray/late flick is a no-op" pattern.
    @discardableResult
    func handleHookSetFlick() -> Bool {
        guard isBiteWindowActive else { return false }
        isBiteWindowActive = false
        biteWindowProgress = 0
        biteAttemptsUsed = 0

        let species = FishCatalog.randomSpecies(unlockedTiers: progressionStore.unlockedTiers)
        currentSpecies = species
        let window = sizeRollWindow
        currentWeight = Self.biasedRoll(in: species.weightRange, floorRatio: window.floor, ceilingRatio: window.ceiling)
        currentLength = Self.biasedRoll(in: species.lengthRange, floorRatio: window.floor, ceilingRatio: window.ceiling)
        hasFishOnHook = true
        isFishInterested = false
        lineTension = config.initialTension

        // ADR-093: the hook-set flick's own follow-through (the player's hand/arm naturally
        // continuing to move for a beat right after the gesture that just fired) can register as
        // one or more further, genuinely separate flicks — each one immediately shaving
        // `fightFlickRelief` off a `lineTension` that was *just* set to `initialTension`, visibly
        // stepping the tension bar down in hops right at the start of a fight. Suppress
        // `handleFightFlick()` for a short grace window so the player's hand has time to settle
        // before flicks start counting again.
        fightFlickGraceTimer = config.fightFlickGraceDuration

        return true
    }

    /// Call every tick a fish is hooked (`.fishOnHook` or `.reeling`),
    /// whether or not the player is currently reeling. `hookDistance` is the current hook-to-rod
    /// distance World measures; the first tick's value becomes the baseline for the
    /// distance-escape check (ADR-039). Returns the failure that just ended the fight, if any;
    /// `nil` while it continues.
    @discardableResult
    func updateFight(deltaTime: Float, isReeling: Bool, reelSpeed: Float, hookDistance: Float) -> FightFailure? {
        guard hasFishOnHook else { return nil }

        if fightFlickGraceTimer > 0 {
            fightFlickGraceTimer = max(0, fightFlickGraceTimer - deltaTime)
        }

        if fightStartDistance == nil {
            fightStartDistance = hookDistance
        }
        if let start = fightStartDistance, hookDistance > start + effectiveEscapeDistanceAllowance {
            resolve(outcome: .escaped)
            return .escaped
        }

        let reelPull = isReeling ? reelSpeed * config.baseReelTensionRate : 0
        lineTension = min(1, max(0, lineTension + (reelPull - effectiveFishPullRate) * deltaTime))

        if lineTension <= 0 {
            resolve(outcome: .escaped)
            return .escaped
        }
        if lineTension >= 1 {
            resolve(outcome: .lineBreak)
            return .lineBreak
        }
        return nil
    }

    /// Called by `WorldViewModel` the instant Rod reports a flick (`FishingEvent.fightFlick`)
    /// while a fish is hooked (ADR-089, replacing ADR-078's timed QTE-prompt mechanic — "pake aja
    /// movement flick dari semua state yang sama jadi ga perlu bikin flick movement lagi": reuse
    /// the exact same flick gesture/detector as the bite-window hook-set, and make every flick
    /// during a fight always meaningful instead of gating it behind a spawn timer/reaction window
    /// the player has to wait for and could otherwise miss with no visible cause). A no-op outside
    /// a fight entirely, or during `fightFlickGraceTimer` right after hooking (ADR-093), so a
    /// stray flick before/after a fight — or the hook-set flick's own follow-through — never has
    /// an effect. Relief, not a reward that raises tension — same sign as the mechanic this
    /// replaces: a flick relieves the fish's pull before it can spike tension toward the snap edge.
    @discardableResult
    func handleFightFlick() -> Bool {
        guard hasFishOnHook, fightFlickGraceTimer <= 0 else { return false }
        lineTension = max(0, lineTension - config.fightFlickRelief)
        return true
    }

    /// Current haptic rhythm tier for Rod, from `lineTension` (ADR-039). `nil` when no fight is
    /// active. Boundaries sit inside `LineTensionView`'s own zones: below the safe zone's upper
    /// half is `.low`, approaching the snap warning is `.medium`, past ~the snap-warning
    /// threshold is `.high`.
    var tensionBand: TensionBand? {
        guard hasFishOnHook else { return nil }
        if lineTension >= config.tensionBandHighThreshold { return .high }
        if lineTension >= config.tensionBandMediumThreshold { return .medium }
        return .low
    }

    /// m/s the hooked fish drags the hook away from the rod while the
    /// player isn't reeling. World applies this to hook position; this
    /// controller has no entity/position knowledge itself.
    var fishPullSpeed: Float {
        guard hasFishOnHook else { return 0 }
        return config.basePullSpeed * (1 + resistance * config.pullSpeedResistanceMultiplier)
    }

    /// m/s per full (1.0) `RodState.reelSpeed` input, right now — tension-scaled risk/reward:
    /// reeling while `lineTension` is at/below `config.reelSpeedSafeTension` (the safe/green zone)
    /// pulls in at `config.reelPullSpeedSafe`; reeling with tension pushed up to/past
    /// `config.reelSpeedDangerTension` (the near-snap red zone) pulls in at
    /// `config.reelPullSpeedDanger` instead — faster by default — rewarding a player willing to
    /// hold tension there rather than backing off to safety. Linearly interpolates between the two
    /// thresholds. World's `reelHook(deltaTime:)` reads this in place of a flat constant.
    ///
    /// ADR-119: the tension-scaled base above is then dragged down by `resistance` (same species x
    /// rolled-size driver as `fishPullSpeed`) — previously this whole property had zero species
    /// dependency, so reeling in a Grouper and a Marlin felt identical despite `fishPullSpeed`
    /// (the fish's own idle-drift speed) already differing. Now both sides of the tug-of-war scale
    /// with difficulty, not just the passive one.
    var reelPullSpeed: Float {
        let low = config.reelSpeedSafeTension
        let high = config.reelSpeedDangerTension
        let base: Float
        if lineTension <= low {
            base = config.reelPullSpeedSafe
        } else if lineTension >= high {
            base = config.reelPullSpeedDanger
        } else {
            let t = (lineTension - low) / max(0.0001, high - low)
            base = config.reelPullSpeedSafe + (config.reelPullSpeedDanger - config.reelPullSpeedSafe) * t
        }
        let dragFactor = max(config.minimumReelSpeedFactor, 1 - resistance * config.reelSpeedResistanceDrag)
        return base * dragFactor
    }

    /// Call when the hook reaches the rod while a fish is attached.
    func resolveCatch() {
        guard hasFishOnHook else { return }
        caughtCount += 1
        resolve(outcome: .caught)
    }

    private func resolve(outcome: FishCatchResult.Outcome) {
        guard let species = currentSpecies else { return }

        var stars = 0
        var coins = 0
        var isNewRecord = false
        if outcome == .caught {
            stars = Self.stars(forWeight: currentWeight, in: species.weightRange)
            coins = Self.coins(baseValue: species.value, stars: stars)
            isNewRecord = recordStore.recordCatch(speciesID: species.id, weight: currentWeight)

            let levelAfter = progressionStore.recordCatch(tier: species.tier)
            if levelAfter > currentLevel {
                levelUpAnnouncement = Self.announcement(forLevel: levelAfter)
            }
            currentLevel = levelAfter
        }

        lastCatchResult = FishCatchResult(
            speciesName: species.name,
            speciesID: species.id,
            weight: currentWeight,
            length: currentLength,
            outcome: outcome,
            stars: stars,
            coins: coins,
            isNewRecord: isNewRecord
        )

        hasFishOnHook = false
        isFishInterested = false
        currentSpecies = nil
        lineTension = 0
        interestTimer = Float.random(in: 0.8...2.0)
        fightStartDistance = nil
        fightFlickGraceTimer = 0
    }

    /// 1...5, from how close the catch weight is to the species' max.
    private static func stars(forWeight weight: Double, in range: FishSpeciesRange) -> Int {
        let span = max(0.0001, range.max - range.min)
        let ratio = min(1, max(0, (weight - range.min) / span))
        return 1 + Int((ratio * 4).rounded())
    }

    /// Bigger fish (more stars) pay out modestly more than the species base.
    private static func coins(baseValue: Int, stars: Int) -> Int {
        let multiplier = 0.6 + 0.1 * Double(stars)
        return max(1, Int((Double(baseValue) * multiplier).rounded()))
    }

    /// Player-facing text for `levelUpAnnouncement` when a catch crosses a `ProgressionStore`
    /// threshold. `nil` is unreachable in practice (`recordCatch` only ever returns 1, 2, or 3),
    /// kept exhaustive rather than force-unwrapped so a future Level 4 doesn't silently misfire.
    private static func announcement(forLevel level: Int) -> String? {
        switch level {
        case 2: return "Medium fish have entered the lake!"
        case 3: return "Scott has appeared. Catch him!"
        default: return nil
        }
    }

    /// Which third of `maxExpectedCastDistance` the current cast landed in — matches
    /// `CastMeterView`'s green/yellow/red thirds of the power bar 1:1 (ADR-061), so the zone the
    /// player watched the flick land in on the meter is the same zone that gates fish size here.
    private enum CastZone {
        case green
        case yellow
        case red
    }

    private var castZone: CastZone {
        let ratio = min(1, max(0, currentCastDistance / maxExpectedCastDistance))
        if ratio < 1.0 / 3.0 { return .green }
        if ratio < 2.0 / 3.0 { return .yellow }
        return .red
    }

    /// Weight/length roll window, as a 0...1 floor/ceiling ratio within the species' own range,
    /// for the current `castZone` (ADR-061) — chosen so the resulting `stars(forWeight:)` output
    /// always lands in the advertised tier: green -> 1-2 stars, yellow -> 3-4 stars, red -> 4-5
    /// stars (the biggest). Derived by inverting `stars(forWeight:in:)`'s own
    /// `1 + round(4 * ratio)` formula at each star boundary, so this is a hard floor+ceiling window
    /// per zone, not just a cap on top of the species' full range — a short cast can no longer
    /// occasionally roll a big fish just by chance.
    private var sizeRollWindow: (floor: Float, ceiling: Float) {
        switch castZone {
        case .green: return (0.0, 0.375)
        case .yellow: return (0.375, 0.875)
        case .red: return (0.625, 1.0)
        }
    }

    /// Rolls a value in `range`, bounded to `[range.min + span * floorRatio, range.min + span *
    /// ceilingRatio]` instead of the full range — used so a fish's rolled weight/length (and thus,
    /// via `sizeRatio` below, its resistance) is bounded by which `castZone` the cast that hooked
    /// it landed in.
    private static func biasedRoll(in range: FishSpeciesRange, floorRatio: Float, ceilingRatio: Float) -> Double {
        let lowRatio = Double(min(1, max(0, floorRatio)))
        let highRatio = Double(min(1, max(0, ceilingRatio)))
        let floor = range.min + (range.max - range.min) * lowRatio
        let ceiling = range.min + (range.max - range.min) * highRatio
        return Double.random(in: floor...max(floor, ceiling))
    }

    private var effectiveFishPullRate: Float {
        config.baseFishPullRate * (1 + resistance * config.pullRateResistanceMultiplier)
    }

    /// `escapeDistanceAllowance`, tightened for tougher fish — see
    /// `FishFightConfig.escapeAllowanceResistancePenalty`'s doc comment.
    private var effectiveEscapeDistanceAllowance: Float {
        max(
            config.minEscapeDistanceAllowance,
            config.escapeDistanceAllowance - resistance * config.escapeAllowanceResistancePenalty
        )
    }

    /// Species `resistance` is a ceiling, not a flat value: the actual fight
    /// difficulty scales with how big *this* catch rolled relative to the
    /// species' own range, via `sizeRatio`. A fish that rolled near its
    /// species' minimum weight/length fights closer to the base rate; one
    /// near the max fights at the full species `resistance`.
    private var resistance: Float {
        guard let species = currentSpecies else { return 0 }
        return Float(species.resistance) * sizeRatio
    }

    /// 0 (rolled at/near the species' min weight*length) ... 1 (rolled
    /// at/near its max), from where `currentWeight * currentLength` falls
    /// between the species' min and max weight*length product.
    private var sizeRatio: Float {
        guard let species = currentSpecies else { return 0 }
        let minProduct = species.weightRange.min * species.lengthRange.min
        let maxProduct = species.weightRange.max * species.lengthRange.max
        let span = max(0.0001, maxProduct - minProduct)
        let product = currentWeight * currentLength
        return Float(min(1, max(0, (product - minProduct) / span)))
    }
}
