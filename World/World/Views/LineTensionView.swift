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
    /// Which way the hooked fish is currently pulling, during the juking sub-phase — `nil`
    /// whenever that phase isn't active. The player must lean the rod the *opposite* way; shown
    /// here (not on Rod) since Rod owns no gameplay HUD.
    let fightDirection: FishFightController.FightDirection?

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

                if let fightDirection {
                    HStack {
                        Label("Fish pulling", systemImage: fightDirection == .left ? "arrow.left" : "arrow.right")
                            .foregroundStyle(.orange)
                        Spacer()
                        Label("Lean rod", systemImage: fightDirection == .left ? "arrow.right" : "arrow.left")
                            .foregroundStyle(.cyan)
                    }
                    .font(.caption.bold())
                }
            }
        }
    }
}
