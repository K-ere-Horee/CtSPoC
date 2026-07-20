//
//  HapticManager.swift
//  Rod
//
//  Created by Calzy Akmal Indyramdhani on 17/07/26.
//

import CoreHaptics

final class HapticManager {

    private var engine: CHHapticEngine?

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            let engine = try CHHapticEngine()
            engine.stoppedHandler = { _ in }
            try engine.start()
            self.engine = engine
        } catch {
            self.engine = nil
        }
    }

    func cast() {
        playTransient(intensity: 0.75, sharpness: 0.5)
    }

    func splash() {
        playTransient(intensity: 0.45, sharpness: 0.15)
    }

    func reelTick() {
        playTransient(intensity: 0.4, sharpness: 0.75)
    }

    func fishBite() {
        playPattern([
            (0.85, 0.4, 0),
            (0.75, 0.35, 0.18),
            (0.75, 0.35, 0.28),
            (0.85, 0.4, 0.55)
        ])
    }

    func catchFish() {
        playPattern([
            (1.0, 0.7, 0),
            (0.6, 0.3, 0.18)
        ])
    }

    func lineBreak() {
        playTransient(intensity: 1.0, sharpness: 1)
    }

    func fishEscaped() {
        playPattern([
            (0.7, 0.45, 0),
            (0.55, 0.35, 0.12),
            (0.35, 0.25, 0.26)
        ])
    }

    /// A single gentle pulse, repeated slowly and externally by
    /// `FishingHaptics.interestPulse(now:)` while a fish is interested but
    /// hasn't bitten. Deliberately softer/duller than `fishBite()`.
    func fishInterested() {
        playTransient(intensity: 0.35, sharpness: 0.2)
    }

    /// One tap of the continuous fight rhythm (ADR-039); repeated externally by
    /// `FishingHaptics.fightPulse(now:)` at the active tension band's interval, with the band
    /// deciding intensity/sharpness — `HapticManager` stays band-agnostic.
    func fightTick(intensity: Float, sharpness: Float) {
        playTransient(intensity: intensity, sharpness: sharpness)
    }

    private func playTransient(intensity: Float, sharpness: Float) {
        playPattern([(intensity, sharpness, 0)])
    }

    private func playPattern(_ pulses: [(Float, Float, TimeInterval)]) {
        guard let engine else { return }

        do {
            try engine.start()
            let events = pulses.map { intensity, sharpness, time in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: time
                )
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            return
        }
    }
}
