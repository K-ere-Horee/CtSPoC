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

    private let initialTension: Float = 0.5
    /// Tension/sec drained by the fish pulling away while not countered.
    private let baseFishPullRate: Float = 0.15
    /// Tension/sec gained per unit `reelSpeed` while actively reeling.
    private let baseReelTensionRate: Float = 0.5
    /// m/s the hook drifts away from the rod while the fish pulls unopposed.
    private let basePullSpeed: Float = 0.4

    private var interestTimer = Float.random(in: 0.8...2.0)
    private var biteTimer: Float = 0
    private var currentSpecies: FishSpecies?
    private var currentWeight: Double = 0
    private var currentLength: Double = 0

    private let recordStore: FishRecordStore

    init(recordStore: FishRecordStore = FishRecordStore()) {
        self.recordStore = recordStore
    }

    /// Call every tick a new cast lands in the water.
    func resetForNewCast() {
        hasFishOnHook = false
        isFishInterested = false
        currentSpecies = nil
        lineTension = 0
        interestTimer = Float.random(in: 0.8...2.0)
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
        currentWeight = species.weightRange.randomValue()
        currentLength = species.lengthRange.randomValue()
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

    private var effectiveFishPullRate: Float {
        baseFishPullRate * (1 + resistance)
    }

    private var resistance: Float {
        Float(currentSpecies?.resistance ?? 0)
    }
}
