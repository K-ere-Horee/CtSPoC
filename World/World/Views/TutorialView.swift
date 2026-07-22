//
//  TutorialView.swift
//  World
//
//  First-time onboarding overlay shown over the game scene: a sequence of
//  tap-to-advance steps explaining the Rod <-> World casting flow.
//

import SwiftUI

private struct TutorialStep {
    let text: String
    let illustration: String?
}

private let tutorialSteps: [TutorialStep] = [
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

/// Tap-anywhere-to-advance tutorial overlay. Composed on top of the live game scene by
/// `ContentView`'s own overlay `ZStack` (ADR-087 — ported from `feat/ui-slice`'s `RootView`,
/// which originally composed it the same way, just via a different top-level router); renders no
/// background of its own so the live game scene stays visible behind it.
struct TutorialView: View {
    let onFinished: () -> Void

    @State private var stepIndex = 0
    private let labelWidth: CGFloat = 569

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: advance)

            bubble(for: tutorialSteps[stepIndex])
                .padding(.leading, 24)
                .padding(.top, 32)
                .allowsHitTesting(false)
        }
    }

    private func advance() {
        if stepIndex < tutorialSteps.count - 1 {
            stepIndex += 1
        } else {
            onFinished()
        }
    }

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
        TutorialView(onFinished: {})
    }
}
