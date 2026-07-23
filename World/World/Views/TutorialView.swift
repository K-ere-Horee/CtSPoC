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
    let illustration: String
}

/// ADR-135: image-only content, no positioning of its own — `ContentView` mounts this as the first
/// element of the same top-center `VStack` `CastMeterView`/`LineTensionView` already live in
/// (rather than as an independent overlay), so the tutorial artwork sits directly above those two
/// meters while showing, and they fall back to that VStack's normal top slot on their own the
/// instant `isShowingTutorial` goes false — no separate "restore position" logic needed. No text,
/// no card/bubble chrome, no local `@State`, no tap gesture. Every step gates on a real gameplay
/// moment rather than a manual "Next" press, except `.intro` (still Rod's "Next"/"Skip Intro"
/// buttons) — see `WorldViewModel`'s `TutorialStepKind`/`advanceTutorial(to:)` for the full state
/// machine. Only shown once per progression cycle (`WorldViewModel.handleState(_:)`'s
/// `hasSeenTutorial` gate, reset by `resetProgression()`) instead of on every "Start Fishing."
struct TutorialView: View {
    /// Every step's illustration, in order — the single source of truth for both this view's
    /// rendering and `WorldViewModel`'s `TutorialStepKind` (whose raw values are indices into this
    /// array), so the two can never drift apart. Loose `World/World/Assets/Tutorials/*.png` files
    /// (loaded via `bundleImage(_:)`, not an asset-catalog `Image(_:)`), one per step.
    static let steps: [TutorialStep] = [
        TutorialStep(illustration: "tutorial_1_intro"),
        TutorialStep(illustration: "tutorial_2_start_cast"),
        TutorialStep(illustration: "tutorial_3_cast"),
        TutorialStep(illustration: "tutorial_4_wait"),
        TutorialStep(illustration: "tutorial_5_reel_fight"),
        TutorialStep(illustration: "tutorial_6_end"),
    ]

    let stepIndex: Int

    /// ADR-134: "resize x2 semua" — double the width the artwork rendered at before this pass (was
    /// 340, now 680) now that it's the only thing on screen rather than sharing a bubble with text.
    private static let illustrationWidth: CGFloat = 680

    var body: some View {
        if steps.indices.contains(stepIndex) {
            bundleImage(steps[stepIndex].illustration)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: Self.illustrationWidth)
                .allowsHitTesting(false)
        }
    }

    private var steps: [TutorialStep] { Self.steps }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        TutorialView(stepIndex: 0)
    }
}
