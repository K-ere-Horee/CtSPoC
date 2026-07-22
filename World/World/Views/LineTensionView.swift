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

                // ADR-089: flicking the rod forward eases tension at any point during a fight —
                // no prompt to wait for, so there's nothing to show a banner for here anymore
                // (see `BiteAlertView` for the one remaining timed prompt, the pre-hook bite
                // window).
            }
        }
    }
}
