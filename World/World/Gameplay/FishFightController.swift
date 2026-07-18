//
//  FishFightController.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 18/07/26.
//

import Shared
import Combine

/// Owns the bite/fight/catch simulation and bookkeeping for the single
/// active fish. `WorldViewModel` drives it from `HookPhase` transitions and
/// reports the resolved outcome as a `FishingEvent`; this controller has no
/// knowledge of transport, hook entities, or RealityKit.
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

    @Published private(set) var hasFishOnHook = false
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

    private var biteTimer = Float.random(in: 1.5...4.0)
    private var currentSpecies: FishSpecies?
    private var currentWeight: Double = 0
    private var currentLength: Double = 0

    /// Call every tick a new cast lands in the water.
    func resetForNewCast() {
        hasFishOnHook = false
        currentSpecies = nil
        lineTension = 0
        biteTimer = Float.random(in: 1.5...4.0)
    }

    /// Call every tick while searching (`.hookInWater`). Returns `true` the
    /// tick a fish grabs the hook.
    @discardableResult
    func updateSearching(deltaTime: Float) -> Bool {
        guard !hasFishOnHook else { return false }
        biteTimer -= deltaTime
        guard biteTimer <= 0 else { return false }

        let species = FishCatalog.randomSpecies()
        currentSpecies = species
        currentWeight = species.weightRange.randomValue()
        currentLength = species.lengthRange.randomValue()
        hasFishOnHook = true
        lineTension = initialTension
        return true
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
        lastCatchResult = FishCatchResult(
            speciesName: species.name,
            weight: currentWeight,
            length: currentLength,
            outcome: outcome
        )
        hasFishOnHook = false
        currentSpecies = nil
        lineTension = 0
        biteTimer = Float.random(in: 1.5...4.0)
    }

    private var effectiveFishPullRate: Float {
        baseFishPullRate * (1 + resistance)
    }

    private var resistance: Float {
        Float(currentSpecies?.resistance ?? 0)
    }
}
