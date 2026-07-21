//
//  OnboardingView.swift
//  World
//

import SwiftUI

/// First-run (or on-demand, via Main Menu's "How to Play") walkthrough covering what the game is,
/// the main objective, and how the tier/level unlock system works — closes the "World Tutorial"
/// gap flagged open since ADR-029/038 (`GAMEPLAY_ARCHITECTURE_V1.md`: "World owns... Tutorial").
///
/// Deliberately does *not* include calibration instructions itself — that's
/// `CalibrationGuidanceView`, a separately reusable, live/step-reactive component shown next (from
/// the Main Menu, once this completes) so the exact same guidance also covers any later
/// recalibration, not just the player's very first pass through it.
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var pageIndex = 0

    private let pages: [Page] = [
        Page(
            systemImage: "figure.fishing",
            title: "Welcome to Catch the Scott",
            body: "A two-device fishing experience. Hold your phone like a real fishing rod \u{2014} cast, reel, and fight fish with it \u{2014} while the action plays out here, on this screen."
        ),
        Page(
            systemImage: "trophy.fill",
            title: "Your Goal",
            body: "Catch fish to grow your collection and work your way up through the lake's tiers. Somewhere out there is Scott \u{2014} the legendary catch this game is named for. Land him to complete your journey."
        ),
        Page(
            systemImage: "chart.bar.fill",
            title: "Levels & Fish Tiers",
            body: "Catch 3 small fish to unlock medium fish.\nCatch 5 medium fish to unlock big fish.\nCatch 10 big fish to unlock Scott.\nCatch Scott to complete the game."
        )
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: pages[pageIndex].systemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(.white)

                VStack(spacing: 14) {
                    Text(pages[pageIndex].title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(pages[pageIndex].body)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                pageDots

                Spacer()

                HStack(spacing: 16) {
                    if pageIndex > 0 {
                        Button("Back") { pageIndex -= 1 }
                            .buttonStyle(.bordered)
                            .tint(.white)
                    }

                    Button(isLastPage ? "Play" : "Next") {
                        if isLastPage {
                            onComplete()
                        } else {
                            pageIndex += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 40)
        }
        // A separate `.overlay`, not another raw `ZStack` child — putting the button directly in
        // the ZStack alongside the main content and giving the ZStack `alignment: .topTrailing`
        // (an earlier version of this file did exactly that) applies that same alignment to every
        // child, including the main VStack, which isn't full-width — it visibly got pushed into
        // the top-right corner instead of staying centered. An overlay keeps the ZStack's own
        // (default, centered) alignment untouched and positions only the button.
        .overlay(alignment: .topTrailing) {
            Button("Skip Intro", action: onComplete)
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.5))
                .padding(20)
        }
    }

    private var isLastPage: Bool { pageIndex == pages.count - 1 }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Circle()
                    .fill(index == pageIndex ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private struct Page {
        let systemImage: String
        let title: String
        let body: String
    }
}
