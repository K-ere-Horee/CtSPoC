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

    /// What `updateSearching` just did this tick, if anything.
    enum SearchEvent {
        /// A fish became interested but hasn't bitten yet.
        case interested
        /// A fish just bit; `hasFishOnHook` is now `true`.
        case bite
    }

    @Published private(set) var hasFishOnHook = false
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

    private let initialTension: Float = 0.5
    /// Tension/sec drained by the fish pulling away while not countered.
    private let baseFishPullRate: Float = 0.15
    /// Tension/sec gained per unit `reelSpeed` while actively reeling.
    private let baseReelTensionRate: Float = 0.5
    /// m/s the hook drifts away from the rod while the fish pulls unopposed.
    private let basePullSpeed: Float = 0.4
    /// Rough max horizontal distance `WorldViewModel`'s projectile physics
    /// can produce at full charge, level release (castSpeed ~4.8 m/s, 0.65
    /// rad launch angle, ~0.65 m drop to water, gravity 2.2). Only used to
    /// normalize `castDistance` into a 0...1 ratio; retune if launch physics
    /// change.
    private let maxExpectedCastDistance: Float = 10.0
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

    private let recordStore: FishRecordStore

    init(recordStore: FishRecordStore = FishRecordStore()) {
        self.recordStore = recordStore
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

        let species = FishCatalog.randomSpecies()
        currentSpecies = species
        currentWeight = Self.biasedRoll(in: species.weightRange, ceilingRatio: sizeCeilingRatio)
        currentLength = Self.biasedRoll(in: species.lengthRange, ceilingRatio: sizeCeilingRatio)
        hasFishOnHook = true
        isFishInterested = false
        lineTension = initialTension
        return .bite
    }

    /// Call every tick a fish is hooked (`.fishOnHook` or `.reeling`),
    /// whether or not the player is currently reeling. Returns the failure
    /// that just ended the fight, if any; `nil` while it continues.
    @discardableResult
    func updateFight(deltaTime: Float, isReeling: Bool, reelSpeed: Float) -> FightFailure? {
        guard hasFishOnHook else { return nil }

        let reelPull = isReeling ? reelSpeed * baseReelTensionRate : 0
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

    /// m/s the hooked fish drags the hook away from the rod while the
    /// player isn't reeling. World applies this to hook position; this
    /// controller has no entity/position knowledge itself.
    var fishPullSpeed: Float {
        guard hasFishOnHook else { return 0 }
        return basePullSpeed * (1 + resistance * 0.5)
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
        baseFishPullRate * (1 + resistance)
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
