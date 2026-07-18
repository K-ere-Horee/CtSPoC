//
//  FishingHaptics.swift
//  Rod
//

import Foundation
import Shared

final class FishingHaptics {

    private let haptics: HapticManager
    private var lastReelTick = Date.distantPast

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
        case .fishBite:
            haptics.fishBite()
        case .fishEscaped:
            haptics.fishEscaped()
        case .lineBreak:
            haptics.lineBreak()
        case .catchFish:
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
}
