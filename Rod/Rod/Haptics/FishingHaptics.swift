//
//  FishingHaptics.swift
//  Rod
//
//  Created by Calzy Akmal Indyramdhani on 17/07/26.
//

import Foundation
import Shared

final class FishingHaptics {

    private let haptics: HapticManager
    private var lastReelTick = Date.distantPast
    private var lastInterestPulse = Date.distantPast
    private(set) var isFishInterested = false

    private let interestPulseInterval: TimeInterval = 1.1

    init(haptics: HapticManager = HapticManager()) {
        self.haptics = haptics
    }

    func handle(_ event: FishingEvent) {
        switch event {
        case .cast:
            haptics.cast()
        case .hookSplash:
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
            haptics.fishEscaped()
        case .lineBreak:
            isFishInterested = false
            haptics.lineBreak()
        case .catchFish:
            isFishInterested = false
            haptics.catchFish()
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

    /// Call when `HookPhase` leaves `.hookInWater`, so a stale interest
    /// signal can't keep pulsing after the fish bit, escaped, or a new cast
    /// began.
    func stopInterest() {
        isFishInterested = false
    }
}
