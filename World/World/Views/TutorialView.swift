//
//  TutorialView.swift
//  World
//
//  First-time onboarding overlay shown over the game scene, driven entirely by
//  `WorldViewModel.tutorialStepIndex` — advanced/skipped from Rod's own "Next"/
//  "Skip Tutorial" buttons (ADR-117), not by tapping this view.
//

import SwiftUI

struct TutorialStep {
    let text: String
    let illustration: String?
}

/// ADR-117: centered, pure-display overlay — no local `@State`, no tap gesture. Rod drives
/// `stepIndex` via `NetworkMessage.tutorialState`/`WorldViewModel.tutorialStepIndex`, replacing the
/// old tap-anywhere-on-World-to-advance interaction ("cuma click click doang") with real "Next"/
/// "Skip Tutorial" buttons living on the device the player is actually holding. Also only shown
/// once per progression cycle now (`WorldViewModel.handleState(_:)`'s `hasSeenTutorial` gate,
/// reset by `resetProgression()`) instead of on every "Start Fishing."
struct TutorialView: View {
    /// Every step's copy, in order — the single source of truth for both this view's rendering and
    /// `WorldViewModel`'s step-count/advance-vs-dismiss logic, so the two can never drift apart.
    static let steps: [TutorialStep] = [
        TutorialStep(
            text: "To catch the fish, you must throw your rod. But first, you must connect the rod with your phone.",
            illustration: nil
        ),
        TutorialStep(
            text: "Press the “Calibrate” button on your phone!",
            illustration: nil
        ),
        TutorialStep(
            text: "Pull back your phone slightly, then flick forward!",
            illustration: "HandTutor"
        ),
        TutorialStep(
            text: "Wait for a fish to bite!",
            illustration: nil
        ),
        TutorialStep(
            text: "Gotchaa!!!",
            illustration: "HandTutor"
        ),
        TutorialStep(
            text: "Well done! Continue your journey to claim more fish and rewards.",
            illustration: nil
        ),
    ]

    let stepIndex: Int
    private let labelWidth: CGFloat = 569

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if steps.indices.contains(stepIndex) {
                bubble(for: steps[stepIndex])
                    .allowsHitTesting(false)
            }
        }
    }

    private var steps: [TutorialStep] { Self.steps }

    /// Fish-overlapping-label bubble, fixed to `labelWidth` with the text
    /// wrapping to fit inside it.
    private func bubble(for step: TutorialStep) -> some View {
        ZStack(alignment: .leading) {
            VStack(alignment: .center, spacing: 10) {
                Text(step.text)
                    .font(.fredoka(18))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let illustration = step.illustration {
                    Image(illustration)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 56)
                }
            }
            .padding(.leading, 66)
            .padding(.trailing, 24)
            .padding(.vertical, 20)
            .frame(width: labelWidth, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(hex: "3B2818").opacity(0.81))
            )
            .padding(.leading, 70)

            Image("FrameIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 140)
        }
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        TutorialView(stepIndex: 0)
    }
}
