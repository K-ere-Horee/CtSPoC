//
//  FishingHaptics.swift
//  Rod
//
//  Created by Calzy Akmal Indyramdhani on 17/07/26.
//

import Foundation
import Shared

final class FishingHaptics {

    /// Continuous fight-haptic rhythm tier (ADR-039), set by World's `reelTension*` events and
    /// rendered by `fightPulse(now:)`. Maps to `GAMEPLAY_ARCHITECTURE_V1.md`'s
    /// resistance-through-rhythm spec: spaced taps -> regular taps -> rapid near-continuous taps.
    /// Rhythm/intensity/sharpness per band live in `FishFightConfig` (ADR-039), not here — see
    /// `parameters(for:)`.
    enum FightBand {
        case low
        case medium
        case high
    }

    private let haptics: HapticManager
    /// Shared with `WorldViewModel`'s `FishFightController` conceptually — both should be
    /// constructed with the same `FishFightConfig` values so Rod's haptic rhythm always matches
    /// the tension bands World is actually computing. See `FishFightConfig`'s own doc comment.
    private let config: FishFightConfig
    private var lastReelTick = Date.distantPast
    private var lastInterestPulse = Date.distantPast
    private var lastFightPulse = Date.distantPast
    private(set) var isFishInterested = false
    private(set) var fightBand: FightBand?

    private let interestPulseInterval: TimeInterval = 1.1

    init(haptics: HapticManager = HapticManager(), config: FishFightConfig = FishFightConfig()) {
        self.haptics = haptics
        self.config = config
    }

    private func parameters(for band: FightBand) -> (interval: TimeInterval, intensity: Float, sharpness: Float) {
        switch band {
        case .low:
            return (config.lowBandInterval, config.lowBandIntensity, config.lowBandSharpness)
        case .medium:
            return (config.mediumBandInterval, config.mediumBandIntensity, config.mediumBandSharpness)
        case .high:
            return (config.highBandInterval, config.highBandIntensity, config.highBandSharpness)
        }
    }

    func handle(_ event: FishingEvent) {
        switch event {
        case .cast:
            fightBand = nil
            haptics.cast()
        case .hookSplash:
            fightBand = nil
            haptics.splash()
        case .reelTick:
            haptics.reelTick()
        case .fishInterested:
            isFishInterested = true
            lastInterestPulse = Date()
            haptics.fishInterested()
        case .fishBite:
            isFishInterested = false
            haptics.fishBite()
        case .fishEscaped:
            isFishInterested = false
            fightBand = nil
            haptics.fishEscaped()
        case .lineBreak:
            isFishInterested = false
            fightBand = nil
            haptics.lineBreak()
        case .catchFish:
            isFishInterested = false
            fightBand = nil
            haptics.catchFish()
        case .reelTensionLow:
            isFishInterested = false
            fightBand = .low
        case .reelTensionMedium:
            isFishInterested = false
            fightBand = .medium
        case .reelTensionHigh:
            isFishInterested = false
            fightBand = .high
        }
    }

    func reelTick(reelSpeed: Float, now: Date = Date()) {
        guard reelSpeed > 0 else { return }

        let interval = max(0.06, 0.25 - TimeInterval(reelSpeed) * 0.16)
        guard now.timeIntervalSince(lastReelTick) >= interval else { return }

        lastReelTick = now
        haptics.reelTick()
    }

    /// Call every motion sample; throttles itself to `interestPulseInterval`
    /// and no-ops unless a `.fishInterested` event is currently active.
    func interestPulse(now: Date = Date()) {
        guard isFishInterested else { return }
        guard now.timeIntervalSince(lastInterestPulse) >= interestPulseInterval else { return }

        lastInterestPulse = now
        haptics.fishInterested()
    }

    /// Call every motion sample; throttles itself to the active band's interval and no-ops
    /// unless a fight tension band is currently set. Same recurring-callback pattern as
    /// `interestPulse(now:)`.
    func fightPulse(now: Date = Date()) {
        guard let fightBand else { return }
        let params = parameters(for: fightBand)
        guard now.timeIntervalSince(lastFightPulse) >= params.interval else { return }

        lastFightPulse = now
        haptics.fightTick(intensity: params.intensity, sharpness: params.sharpness)
    }

    /// Call when `HookPhase` leaves `.hookInWater`, so a stale interest
    /// signal can't keep pulsing after the fish bit, escaped, or a new cast
    /// began.
    func stopInterest() {
        isFishInterested = false
    }

    /// Call when `HookPhase` leaves the fight phases (`.fishOnHook`/`.reeling`), so a stale
    /// tension band can't keep buzzing after the fight ended — belt-and-suspenders alongside the
    /// fight-ending events above, which also clear it.
    func stopFight() {
        fightBand = nil
    }
}
