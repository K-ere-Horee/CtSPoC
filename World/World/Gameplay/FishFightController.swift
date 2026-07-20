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

    /// Which way a hooked fish is currently pulling, during the juking sub-phase (see
    /// `fightDirection`'s own doc comment). The player must roll the rod the *opposite* way to
    /// counter it — real-fishing "rod-side pressure" — matching this project's own left/right
    /// convention (world/screen space, not rod-relative): `.left` means the fish pulls toward
    /// the player's left, so the player must roll the rod toward their right.
    enum FightDirection {
        case left
        case right
    }

    @Published private(set) var hasFishOnHook = false
    /// Which way a hooked fish is currently pulling, or `nil` when the juking sub-phase isn't
    /// active (either the fight hasn't started, or `fightDirectionRemainingDuration` ran out).
    /// World reads this to both drift the hook visually and show the player which way to counter
    /// (Rod owns no gameplay HUD, so this can't be communicated on the controller itself).
    @Published private(set) var fightDirection: FightDirection?
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
    /// `sizeCeilingRatio` below.
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
    /// Seconds left in the current fight's juking sub-phase; counts down in `updateFight`.
    /// `fightDirection` clears once this reaches 0. `0` whenever no fight is active.
    private var fightDirectionRemainingDuration: Float = 0
    /// Seconds until the next direction flip — "rapid randomizer," reset to a new random interval
    /// every time `fightDirection` flips.
    private var fightDirectionSwitchTimer: Float = 0

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
    /// horizontal distance that cast actually traveled, and caps how big a
    /// fish this cast can hook via `sizeCeilingRatio`.
    func resetForNewCast(castDistance: Float = 0) {
        hasFishOnHook = false
        isFishInterested = false
        currentSpecies = nil
        lineTension = 0
        interestTimer = Float.random(in: 0.8...2.0)
        currentCastDistance = castDistance
        lastCastDistance = castDistance
        fightStartDistance = nil
        fightDirection = nil
        fightDirectionRemainingDuration = 0
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
        currentWeight = Self.biasedRoll(in: species.weightRange, ceilingRatio: sizeCeilingRatio)
        currentLength = Self.biasedRoll(in: species.lengthRange, ceilingRatio: sizeCeilingRatio)
        hasFishOnHook = true
        isFishInterested = false
        lineTension = config.initialTension

        // Fight-direction juking phase starts the instant the fish is hooked — a random 5-10s
        // (config-driven) window during which it darts left/right, on top of the base tension
        // fight above. Requested directly: fish should "geser kanan kiri dengan rapid randomizer"
        // for "beberapa detik" per fight, with the player countering by leaning the rod opposite.
        fightDirection = Bool.random() ? .left : .right
        fightDirectionRemainingDuration = Float.random(in: config.fightDirectionMinDuration...config.fightDirectionMaxDuration)
        fightDirectionSwitchTimer = Float.random(in: config.fightDirectionSwitchMinInterval...config.fightDirectionSwitchMaxInterval)

        return .bite
    }

    /// Call every tick a fish is hooked (`.fishOnHook` or `.reeling`),
    /// whether or not the player is currently reeling. `hookDistance` is the current hook-to-rod
    /// distance World measures; the first tick's value becomes the baseline for the
    /// distance-escape check (ADR-039). `rodRoll` is `RodState.roll` (relative to the calibrated
    /// idle pose) — used only to evaluate the fight-direction counter below; has no effect outside
    /// the juking phase. Returns the failure that just ended the fight, if any; `nil` while it
    /// continues.
    @discardableResult
    func updateFight(deltaTime: Float, isReeling: Bool, reelSpeed: Float, hookDistance: Float, rodRoll: Double) -> FightFailure? {
        guard hasFishOnHook else { return nil }

        if fightStartDistance == nil {
            fightStartDistance = hookDistance
        }
        if let start = fightStartDistance, hookDistance > start + effectiveEscapeDistanceAllowance {
            resolve(outcome: .escaped)
            return .escaped
        }

        let reelPull = isReeling ? reelSpeed * config.baseReelTensionRate : 0
        let directionDelta = updateFightDirection(deltaTime: deltaTime, rodRoll: rodRoll)
        lineTension = min(1, max(0, lineTension + (reelPull - effectiveFishPullRate + directionDelta) * deltaTime))

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

    /// Advances the juking sub-phase (direction flips, phase expiry) and evaluates whether the
    /// player is currently countering the fish's pull correctly, returning a tension/sec delta to
    /// fold into `updateFight`'s main formula — `0` whenever the phase isn't active. Kept as a
    /// separate method purely for readability; it's still just more `lineTension` math, no
    /// entity/RealityKit knowledge crosses into this controller.
    private func updateFightDirection(deltaTime: Float, rodRoll: Double) -> Float {
        guard let direction = fightDirection else { return 0 }

        fightDirectionRemainingDuration -= deltaTime
        guard fightDirectionRemainingDuration > 0 else {
            fightDirection = nil
            return 0
        }

        fightDirectionSwitchTimer -= deltaTime
        if fightDirectionSwitchTimer <= 0 {
            fightDirection = direction == .left ? .right : .left
            fightDirectionSwitchTimer = Float.random(in: config.fightDirectionSwitchMinInterval...config.fightDirectionSwitchMaxInterval)
        }

        // The fish pulls `.left` -> the player must roll the rod toward their right (positive
        // roll, by this project's convention) to counter it, and vice versa — real-fishing
        // "rod-side pressure." `fightDirection` may have just flipped above; re-read it so the
        // very same tick already evaluates against the new direction rather than lagging a frame.
        let isCountering = fightDirection == .left
            ? rodRoll >= config.fightDirectionRollThreshold
            : rodRoll <= -config.fightDirectionRollThreshold
        return isCountering ? -config.fightDirectionCounterRelief : config.fightDirectionPenalty
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
        fightDirection = nil
        fightDirectionRemainingDuration = 0
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

    /// 0.3 (short/no cast) ... 1 (at/near `maxExpectedCastDistance`). Floors
    /// at 0.3 so a short cast can still land a modest fish rather than being
    /// capped at the species' absolute minimum every time.
    private var sizeCeilingRatio: Float {
        let distanceRatio = min(1, max(0, currentCastDistance / maxExpectedCastDistance))
        return 0.3 + 0.7 * distanceRatio
    }

    /// Rolls a value in `range`, capped at `range.min + span * ceilingRatio`
    /// instead of the full range — used so a fish's rolled weight/length
    /// (and thus, via `sizeRatio` below, its resistance) is bounded by how
    /// far the cast that hooked it traveled.
    private static func biasedRoll(in range: FishSpeciesRange, ceilingRatio: Float) -> Double {
        let ratio = Double(min(1, max(0, ceilingRatio)))
        let ceiling = range.min + (range.max - range.min) * ratio
        return Double.random(in: range.min...max(range.min, ceiling))
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
