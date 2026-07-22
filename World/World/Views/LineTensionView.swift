//
//  LineTensionView.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 18/07/26.
//

import SwiftUI

/// ADR-097: restyled to the gradient-capsule + `roll.png` reel cap + live marker structure
/// originally built for `CastMeterView` — a tension gauge is just as well served by that visual
/// language, and the two were getting visually confused for one another. Placed in the same
/// top-center overlay slot `CastMeterView` uses (see `ContentView`), since the two are mutually
/// exclusive in time (charging vs. fighting) and read to the player as one continuous HUD element.
/// Both ends of the bar are still a failure (too low = slack line/lost fish, too high = snapped
/// line from over-reeling); the safe zone in the middle is outlined rather than just inferred.
struct LineTensionView: View {
    let isFighting: Bool
    let tension: Float

    private let dangerLow: Float = 0.15
    private let dangerHigh: Float = 0.85
    private let safeLow: Float = 0.3
    private let safeHigh: Float = 0.7

    private let reelSize: CGFloat = 45
    private let barHeight: CGFloat = 24

    private var warningLabel: String? {
        if tension < dangerLow { return "LOSING FISH" }
        if tension > dangerHigh { return "SNAPPING" }
        return nil
    }

    var body: some View {
        if isFighting {
            VStack(spacing: 6) {
                GeometryReader { geometry in
                    let trackWidth: CGFloat = geometry.size.width - reelSize * 0.5
                    let clampedTension: CGFloat = CGFloat(min(1, max(0, tension)))
                    let safeZoneWidth: CGFloat = CGFloat(safeHigh - safeLow) * trackWidth
                    let safeZoneOffset: CGFloat = reelSize * 0.5 + CGFloat(safeLow) * trackWidth
                    let markerOffset: CGFloat = reelSize * 0.5 + clampedTension * trackWidth - 9

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .yellow, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: barHeight)
                            .padding(.leading, reelSize * 0.5)

                        // Safe zone — the only stretch of the bar where the fish stays hooked
                        // without drifting toward either failure edge.
                        Capsule()
                            .stroke(.white.opacity(0.7), lineWidth: 2)
                            .frame(width: safeZoneWidth, height: barHeight)
                            .offset(x: safeZoneOffset)

                        // Live tension marker — same `fish_sign.png` used for the cast meter's
                        // power marker, for visual consistency between the two mutually exclusive
                        // meters sharing this HUD slot.
                        bundleImage("fish_sign")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: barHeight + 16)
                            .shadow(color: .black.opacity(0.4), radius: 2)
                            .offset(x: markerOffset)

                        bundleImage("roll")
                            .resizable()
                            .scaledToFit()
                            .frame(width: reelSize, height: reelSize)
                    }
                }
                .frame(height: max(barHeight, reelSize))

                if let warningLabel {
                    Text(warningLabel)
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
