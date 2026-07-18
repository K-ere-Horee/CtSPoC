//
//  HapticManager.swift
//  Rod
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
        playTransient(intensity: 0.55, sharpness: 0.45)
    }

    func splash() {
        playTransient(intensity: 0.32, sharpness: 0.12)
    }

    func reelTick() {
        playTransient(intensity: 0.2, sharpness: 0.7)
    }

    func fishBite() {
        playPattern([
            (0.65, 0.35, 0),
            (0.55, 0.3, 0.18),
            (0.55, 0.3, 0.28),
            (0.65, 0.35, 0.55)
        ])
    }

    func catchFish() {
        playPattern([
            (0.95, 0.65, 0),
            (0.45, 0.25, 0.18)
        ])
    }

    func lineBreak() {
        playTransient(intensity: 0.9, sharpness: 1)
    }

    func fishEscaped() {
        playPattern([
            (0.5, 0.4, 0),
            (0.35, 0.3, 0.12),
            (0.2, 0.2, 0.26)
        ])
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
