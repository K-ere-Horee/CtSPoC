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
        /// A fish just bit; `hasFishOnHook` is now `true`.
        case bite
    }

    @Published private(set) var hasFishOnHook = false
    /// Whether a flick-QTE prompt is currently active (ADR-078, replacing the ADR-053 lean-left/
    /// right juke) — the player has `qteReactionWindow` seconds to flick the rod forward before
    /// it counts as a miss. World reads this to show a HUD prompt and to fire a one-shot Rod
    /// haptic alert on the rising edge (Rod owns no gameplay HUD, so this can't be communicated
    /// on the controller itself).
    @Published private(set) var isQTEActive = false
    /// `1.0` the instant a prompt spawns, ticking down to `0.0` as `qteReactionWindow` elapses —
    /// normalized (not raw seconds) so `LineTensionView` doesn't need its own copy of
    /// `config.qteReactionWindow` just to size a progress bar. Meaningless while `!isQTEActive`.
    @Published private(set) var qteProgress: Float = 0
    /// A fish is nearby and interested but hasn't bitten. World may show a
    /// subtle cue; Rod plays a slow periodic haptic while this is `true`.
    @Published private(set) var isFishInterested = false
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
    private var currentSpecies: FishSpecies?
    private var currentWeight: Double = 0
    private var currentLength: Double = 0
    private var currentCastDistance: Float = 0
    /// Hook-to-rod distance on the first `updateFight` tick of the current fight — the baseline
    /// `escapeDistanceAllowance` is measured against. `nil` outside a fight.
    private var fightStartDistance: Float?
    /// Seconds until the next QTE prompt spawns — counts down in `updateFight` whenever
    /// `!isQTEActive`. Re-seeded to a fresh random interval on bite and after every prompt
    /// resolves (success or timeout), so prompts keep recurring for the rest of the fight.
    private var qteSpawnTimer: Float = 0
    /// Seconds left in the *current* active prompt's reaction window — counts down in
    /// `updateFight` whenever `isQTEActive`. Reaching 0 resolves the prompt as a miss.
    private var qteReactionTimer: Float = 0

    private let recordStore: FishRecordStore
    private let progressionStore: ProgressionStore

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

    /// Called by the HUD once it's shown `levelUpAnnouncement` for long enough.
    func dismissLevelUpAnnouncement() {
        levelUpAnnouncement = nil
    }

    /// Resets `ProgressionStore` back to Level 1 (only `.small` catchable) and clears any
    /// in-flight level-up banner, so the player can replay the tier-unlock progression from
    /// scratch — a debug/utility action, not part of the fishing session loop itself.
    func resetProgression() {
        progressionStore.reset()
        currentLevel = progressionStore.level
        levelUpAnnouncement = nil
    }

    /// Call every tick a new cast lands in the water. `castDistance` is the
    /// horizontal distance that cast actually traveled, and gates how big a
    /// fish this cast can hook via `castZone`/`sizeRollWindow`.
    func resetForNewCast(castDistance: Float = 0) {
        hasFishOnHook = false
        isFishInterested = false
        currentSpecies = nil
        lineTension = 0
        interestTimer = Float.random(in: 0.8...2.0)
        currentCastDistance = castDistance
        lastCastDistance = castDistance
        fightStartDistance = nil
        isQTEActive = false
        qteProgress = 0
        qteSpawnTimer = 0
        qteReactionTimer = 0
    }

    /// Call every tick while searching (`.hookInWater`). Returns the search
    /// event that just happened, if any: interest starting, or a bite.
    @discardableResult
    func updateSearching(deltaTime: Float) -> SearchEvent? {
        guard !hasFishOnHook else { return nil }

        guard isFishInterested else {
            interestTimer -= deltaTime
            guard interestTimer <= 0 else { return nil }
            isFishInterested = true
            biteTimer = Float.random(in: 0.8...2.0)
            return .interested
        }

        biteTimer -= deltaTime
        guard biteTimer <= 0 else { return nil }

        let species = FishCatalog.randomSpecies(unlockedTiers: progressionStore.unlockedTiers)
        currentSpecies = species
        let window = sizeRollWindow
        currentWeight = Self.biasedRoll(in: species.weightRange, floorRatio: window.floor, ceilingRatio: window.ceiling)
        currentLength = Self.biasedRoll(in: species.lengthRange, floorRatio: window.floor, ceilingRatio: window.ceiling)
        hasFishOnHook = true
        isFishInterested = false
        lineTension = config.initialTension

        // Flick-QTE prompts start recurring the instant the fish is hooked (ADR-078) — the first
        // one spawns after a random `qteSpawnMinInterval...qteSpawnMaxInterval` delay, not
        // instantly, giving the player a moment to settle into the fight first.
        isQTEActive = false
        qteProgress = 0
        qteSpawnTimer = Float.random(in: config.qteSpawnMinInterval...config.qteSpawnMaxInterval)
        qteReactionTimer = 0

        return .bite
    }

    /// Call every tick a fish is hooked (`.fishOnHook` or `.reeling`),
    /// whether or not the player is currently reeling. `hookDistance` is the current hook-to-rod
    /// distance World measures; the first tick's value becomes the baseline for the
    /// distance-escape check (ADR-039). Returns the failure that just ended the fight, if any;
    /// `nil` while it continues.
    @discardableResult
    func updateFight(deltaTime: Float, isReeling: Bool, reelSpeed: Float, hookDistance: Float) -> FightFailure? {
        guard hasFishOnHook else { return nil }

        if fightStartDistance == nil {
            fightStartDistance = hookDistance
        }
        if let start = fightStartDistance, hookDistance > start + effectiveEscapeDistanceAllowance {
            resolve(outcome: .escaped)
            return .escaped
        }

        let reelPull = isReeling ? reelSpeed * config.baseReelTensionRate : 0
        lineTension = min(1, max(0, lineTension + (reelPull - effectiveFishPullRate) * deltaTime))
        // Disabled for debugging (ADR-078's QTE mechanic) — commented out, not removed. This is
        // the single call site that drives the whole lifecycle: with it out, `isQTEActive` never
        // becomes true, so `qtePrompt`/the "FLICK ROD NOW!" banner never fire, and `handleQTEFlick()`
        // stays a permanent no-op (its own `guard isQTEActive` never passes) even though Rod keeps
        // detecting/sending flicks as normal. Uncomment this one line to re-enable.
        // updateQTE(deltaTime: deltaTime)

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

    /// Advances the flick-QTE spawn/reaction timers (ADR-078) and resolves a prompt's outcome as
    /// an instant `lineTension` adjustment when one occurs — a miss (reaction window expiring) or
    /// a hit via `handleQTEFlick()` below, called separately by `WorldViewModel` the instant Rod
    /// reports a flick. Kept as a separate method purely for readability; still just more
    /// `lineTension` bookkeeping, no entity/RealityKit/network knowledge crosses into this
    /// controller.
    private func updateQTE(deltaTime: Float) {
        if isQTEActive {
            qteReactionTimer -= deltaTime
            qteProgress = max(0, qteReactionTimer / max(0.001, config.qteReactionWindow))
            guard qteReactionTimer > 0 else {
                // Missed it — the reaction window ran out with no flick. Same sign convention the
                // ADR-053 mechanic used for "not countering": a miss reads as the fish's sudden
                // pull going unanswered, spiking tension *up* (toward the snap edge), not down —
                // matching how `effectiveFishPullRate` already drains tension toward 0 on its own
                // every tick regardless, so a miss's risk is specifically snap risk, not escape.
                isQTEActive = false
                qteProgress = 0
                lineTension = min(1, lineTension + config.qteFailurePenalty)
                qteSpawnTimer = Float.random(in: config.qteSpawnMinInterval...config.qteSpawnMaxInterval)
                return
            }
        } else {
            qteSpawnTimer -= deltaTime
            guard qteSpawnTimer <= 0 else { return }
            isQTEActive = true
            qteReactionTimer = config.qteReactionWindow
            qteProgress = 1
        }
    }

    /// Called by `WorldViewModel` the instant Rod reports a flick (`FishingEvent.qteFlick`) during
    /// a fight. A no-op whenever no prompt is currently active — including a flick that arrives
    /// just after a prompt already timed out, or outside a fight entirely (`isQTEActive` can only
    /// be `true` while `hasFishOnHook`) — so a stray/late/unprompted flick never has any effect.
    @discardableResult
    func handleQTEFlick() -> Bool {
        guard isQTEActive else { return false }
        isQTEActive = false
        qteProgress = 0
        // Relief, not a reward that raises tension — same sign as the ADR-053 mechanic's
        // successful counter: a hit relieves the fish's sudden pull before it can spike tension
        // toward the snap edge.
        lineTension = max(0, lineTension - config.qteSuccessRelief)
        qteSpawnTimer = Float.random(in: config.qteSpawnMinInterval...config.qteSpawnMaxInterval)
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
    var reelPullSpeed: Float {
        let low = config.reelSpeedSafeTension
        let high = config.reelSpeedDangerTension
        guard lineTension > low else { return config.reelPullSpeedSafe }
        guard lineTension < high else { return config.reelPullSpeedDanger }
        let t = (lineTension - low) / max(0.0001, high - low)
        return config.reelPullSpeedSafe + (config.reelPullSpeedDanger - config.reelPullSpeedSafe) * t
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
        isQTEActive = false
        qteProgress = 0
        qteSpawnTimer = 0
        qteReactionTimer = 0
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
