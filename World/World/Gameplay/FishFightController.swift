//
//  FishFightController.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 18/07/26.
//

import Shared
import Combine

/// Owns the bite/escape/line-tension simulation and catch bookkeeping for
/// the single active fish. `WorldViewModel` drives it from `HookPhase`
/// transitions and reports the resolved outcome as a `FishingEvent`; this
/// controller has no knowledge of transport, hook entities, or RealityKit.
@MainActor
final class FishFightController: ObservableObject {

    @Published private(set) var hasFishOnHook = false
    /// 0 (slack) ... 1 (snaps). HUD-facing line tension meter.
    @Published private(set) var lineTension: Float = 0
    @Published private(set) var caughtCount = 0
    @Published private(set) var lastCatchResult: FishCatchResult?

    private let baseBiteExpireDuration: Float = 2.5
    private let baseSafeReelSpeed: Float = 0.55
    private let baseTensionRiseRate: Float = 0.8
    private let tensionDecayRate: Float = 0.6

    private var biteTimer = Float.random(in: 1.5...4.0)
    private var biteExpireTimer: Float = 0
    private var currentSpecies: FishSpecies?
    private var currentWeight: Double = 0
    private var currentLength: Double = 0

    /// Call every tick a new cast lands in the water.
    func resetForNewCast() {
        hasFishOnHook = false
        currentSpecies = nil
        lineTension = 0
        biteExpireTimer = 0
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
        biteExpireTimer = effectiveBiteExpireDuration
        return true
    }

    /// Call every tick a fish is hooked but the player isn't reeling.
    /// Returns `true` the tick the fish escapes.
    @discardableResult
    func updateWaiting(deltaTime: Float) -> Bool {
        guard hasFishOnHook else { return false }
        biteExpireTimer -= deltaTime
        guard biteExpireTimer <= 0 else { return false }

        resolve(outcome: .escaped)
        return true
    }

    /// Call instead of `updateWaiting` when reeling pauses mid-fight, so the
    /// escape clock restarts rather than draining silently.
    func pauseFight() {
        guard hasFishOnHook else { return }
        biteExpireTimer = effectiveBiteExpireDuration
    }

    /// Call every tick the player actively reels a hooked fish. Returns
    /// `true` the tick the line snaps.
    @discardableResult
    func updateFighting(deltaTime: Float, reelSpeed: Float) -> Bool {
        guard hasFishOnHook else { return false }

        let overSafe = reelSpeed - effectiveSafeReelSpeed
        if overSafe > 0 {
            lineTension = min(1, lineTension + overSafe * effectiveTensionRiseRate * deltaTime)
        } else {
            lineTension = max(0, lineTension - tensionDecayRate * deltaTime)
        }

        guard lineTension >= 1 else { return false }
        resolve(outcome: .lineBreak)
        return true
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

    private var effectiveBiteExpireDuration: Float {
        max(0.6, baseBiteExpireDuration * (1 - resistance * 0.3))
    }

    private var effectiveSafeReelSpeed: Float {
        max(0.15, baseSafeReelSpeed * (1 - resistance * 0.3))
    }

    private var effectiveTensionRiseRate: Float {
        baseTensionRiseRate * (1 + resistance)
    }

    private var resistance: Float {
        Float(currentSpecies?.resistance ?? 0)
    }
}
