//
//  CalibrationGuidanceView.swift
//  World
//

import Shared
import SwiftUI

/// Live, step-reactive calibration guidance — the World-side half of "Calibration instructions
/// appear entirely in World" (`GAMEPLAY_ARCHITECTURE_V1.md`), a design intent flagged as an open
/// gap since ADR-029/038 and closed by ADR-064. Driven directly by `RodState.calibrationStep`, so
/// it tracks whatever Rod is actually doing in real time — reused both for the very first
/// calibration (surfaced from `MainMenuView`) and any later recalibration mid-session (ADR-064
/// relaxed calibration to any time `HookPhase == .idle`, not only before the first "Start
/// Fishing"), so the exact same guidance covers both without duplicating this text twice.
struct CalibrationGuidanceView: View {
    let step: CalibrationStep

    /// ADR-132: matches the dark-card + white-border language used everywhere else in the HUD
    /// (`ContentView.panelColor`, `CatchCutsceneView.panelColor`, etc.) — this view previously had
    /// no background at all, floating bare text directly over whatever was behind it (the Main
    /// Menu's photo background, or a `.regularMaterial` wrapper only at one of its two call sites),
    /// reading as visually inconsistent with the rest of the screen. Reported directly: "ketika
    /// calibrate di main menu, design nya masih aneh (alias ga ngikutin bahasa design)."
    private static let panelColor = Color(red: 0.16, green: 0.12, blue: 0.09)

    private var title: String {
        switch step {
        case .idle: "Step 1 of 3 \u{2014} Idle Pose"
        case .cast: "Step 2 of 3 \u{2014} Cast Gesture"
        case .reel: "Step 3 of 3 \u{2014} Reel Gesture"
        case .complete: "Calibration Complete"
        }
    }

    private var instruction: String {
        switch step {
        case .idle: "Hold your rod naturally \u{2014} the way you'd rest it while waiting for a bite."
        case .cast: "Perform one natural forward casting motion with your rod."
        case .reel: "Reel naturally for a moment, as if bringing in a catch."
        case .complete: "Your rod is calibrated and ready to fish."
        }
    }

    /// The exact label on Rod's own Calibrate button for this step — mirrors
    /// `Rod/Rod/ContentView.swift`'s `calibrationButtonTitle` so the two can never drift apart in
    /// what they tell the player to press.
    private var rodButtonLabel: String? {
        switch step {
        case .idle: "Capture Idle Pose"
        case .cast: "Capture Cast Gesture"
        case .reel: "Capture Reel Gesture"
        case .complete: nil
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: step == .complete ? "checkmark.circle.fill" : "scope")
                .font(.title)
                .foregroundStyle(step == .complete ? .green : .white)

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(instruction)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            if let rodButtonLabel {
                Text("Press \u{201C}\(rodButtonLabel)\u{201D} on your Rod")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(Self.panelColor, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white, lineWidth: 2))
    }
}
