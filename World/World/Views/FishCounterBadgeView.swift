//
//  FishCounterBadgeView.swift
//  World
//

import SwiftUI

/// Round `fish.png` badge overlapping the leading edge of a dark pill showing progress toward the
/// next tier unlock (e.g. "1/5") — matches a supplied reference design. Replaces the plain
/// "Caught {count}" / "Level {level}" text rows `ContentView` used to show; the last-catch-result
/// row (species/weight/length) lives in its own `LastCatchStatBoxView` instead, since this badge
/// has no room for it.
///
/// ADR-100: both the circular badge and the pill now carry the same solid white border as every
/// other HUD element's rectangle/capsule (`CastMeterView`'s track, `LineTensionView`'s bar,
/// `LastCatchStatBoxView`'s card) — was a faint `.white.opacity(0.25)` ring on the circle only.
struct FishCounterBadgeView: View {
    /// `(caught, needed)` toward the next tier, or `nil` once every tier is unlocked —
    /// `FishFightController.progressTowardNextLevel`, unchanged passthrough.
    let progress: (caught: Int, needed: Int)?
    /// Shown in place of a "caught/needed" fraction once every tier is unlocked, since there's no
    /// longer a meaningful denominator.
    let caughtCount: Int

    private static let badgeColor = Color(red: 0.55, green: 0.42, blue: 0.28)
    private static let pillColor = Color(red: 0.16, green: 0.12, blue: 0.09)

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Self.badgeColor)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                bundleImage("fish_sign")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
            .frame(width: 36, height: 36)
            .zIndex(1)

            Text(progressText)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(minWidth: 64)
                .padding(.vertical, 6)
                .padding(.trailing, 14)
                .padding(.leading, 18)
                .background(Self.pillColor, in: Capsule())
                .overlay(Capsule().stroke(.white, lineWidth: 2))
                .offset(x: -18)
        }
    }

    private var progressText: String {
        guard let progress else { return "\(caughtCount)" }
        return "\(progress.caught)/\(progress.needed)"
    }
}
