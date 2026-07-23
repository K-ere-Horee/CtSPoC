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
///
/// ADR-099: unlike the cast meter, this bar's coloring stays a full edge-to-edge gradient (tension
/// isn't a "fill toward a goal" value — it's a live position that can move either direction across
/// the whole range), so there's no track/fill split to border here. The border instead wraps the
/// entire bar, replacing the earlier partial safe-zone outline — the safe-zone concept is dropped
/// as a distinct visual since the border already frames the bar as a whole and the marker
/// communicates the live position that matters.
struct LineTensionView: View {
    let isFighting: Bool
    let tension: Float

    private let dangerLow: Float = 0.15
    private let dangerHigh: Float = 0.85

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
                            .overlay(Capsule().stroke(.white, lineWidth: 2))
                            .frame(width: trackWidth, height: barHeight)
                            .padding(.leading, reelSize * 0.5)

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
