//
//  LineTensionView.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 18/07/26.
//

import SwiftUI

/// Both ends of the bar are a failure: too low means the line went slack
/// and the fish escaped, too high means it snapped from over-reeling. The
/// safe zone in the middle is shaded so the player can see it, not just
/// infer it from color.
struct LineTensionView: View {
    let isFighting: Bool
    let tension: Float
    /// Whether a flick-QTE prompt is currently active (ADR-078, replacing the ADR-053 lean-left/
    /// right juke) — the player must flick the rod forward (same gesture as a cast release)
    /// before `qteProgress` reaches 0. Shown here (not on Rod) since Rod owns no gameplay HUD.
    let isQTEActive: Bool
    /// `1.0` right when a prompt spawns, ticking down to `0.0` as the reaction window elapses —
    /// drives the shrinking progress bar below. Meaningless while `!isQTEActive`.
    let qteProgress: Float

    private let dangerLow: Float = 0.15
    private let dangerHigh: Float = 0.85
    private let safeLow: Float = 0.3
    private let safeHigh: Float = 0.7

    private var color: Color {
        if tension < dangerLow || tension > dangerHigh { return .red }
        if tension < safeLow || tension > safeHigh { return .yellow }
        return .green
    }

    private var warningLabel: String? {
        if tension < dangerLow { return "LOSING FISH" }
        if tension > dangerHigh { return "SNAPPING" }
        return nil
    }

    var body: some View {
        if isFighting {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Line Tension")
                        .font(.headline)
                    Spacer()
                    if let warningLabel {
                        Text(warningLabel)
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)

                        Capsule()
                            .fill(.green.opacity(0.25))
                            .frame(width: CGFloat(safeHigh - safeLow) * geometry.size.width)
                            .offset(x: CGFloat(safeLow) * geometry.size.width)

                        Capsule()
                            .fill(color)
                            .frame(width: CGFloat(min(1, max(0, tension))) * geometry.size.width)
                    }
                }
                .frame(height: 14)

                HStack {
                    Text("Slack")
                    Spacer()
                    Text("Snap")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if isQTEActive {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("FLICK ROD NOW!", systemImage: "bolt.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.yellow)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.quaternary)
                                Capsule()
                                    .fill(.yellow)
                                    .frame(width: CGFloat(min(1, max(0, qteProgress))) * geometry.size.width)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }
}
