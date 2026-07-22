//
//  CastMeterView.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 15/07/26.
//

import Shared
import SwiftUI

/// **Visual design.** Restyled to match a supplied reference: a smooth gradient pill (was three
/// hard-edged solid-color blocks) capped on the left by `roll.png` (a reel/spool graphic), loaded
/// via the shared `bundleImage(_:)` (see `BundleImage.swift`). The reference itself shows no text
/// at all — the informational rows this view already had (holding duration, resolved
/// power/distance) are kept, since they're real gameplay feedback rather than decoration, but
/// demoted to small, secondary-styled text below the bar so the bar itself is the visual focus,
/// matching the reference's clean look as closely as possible without dropping information the
/// player relies on mid-cast.
///
/// ADR-096: `reelSize`/`barHeight` are 80% of this view's original values — the caller (
/// `ContentView`) now also constrains this view's width to ~40% of screen width and floats it as
/// an overlay, so both dimensions had to shrink to match the smaller footprint of a HUD element
/// rather than a full-width bar.
///
/// ADR-098: the bar is no longer a static full-width gradient with a marker riding on top of it —
/// per a closer look at the reference, it's a dark brown/black track (`Self.darkEnd`, white-
/// bordered) that a green -> yellow -> red gradient fill grows into from the left, proportional to
/// `power`. The fill is a fixed-position gradient clipped to the current fill width (not a
/// gradient stretched to fit the filled portion), so a given power value always reads the same
/// color regardless of how much of the bar is filled. `fish_sign.png` stays as a marker riding the
/// fill's leading edge, since the reference's static example has no live indicator to compare
/// against but the bar needs one.
struct CastMeterView: View {
    let castSolution: CastSolution?
    let power: Float
    let phase: RodMotionPhase
    /// Live seconds held in the backswing/charging zone this attempt (ADR-056) — shown as a raw
    /// timer alongside the normalized power bar, since power is now purely a function of this.
    let holdDuration: TimeInterval

    private var isVisible: Bool {
        phase == .backswing || phase == .charging || phase == .forwardSwing
            || phase == .release || phase == .followThrough
    }

    /// The reel graphic's rendered size — the bar's leading inset is derived from this so the
    /// reel visually caps the bar's left end rather than sitting beside it.
    private let reelSize: CGFloat = 45
    private let barHeight: CGFloat = 24
    private static let darkEnd = Color(red: 0.16, green: 0.12, blue: 0.09)

    var body: some View {
        Group {
            if isVisible {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geometry in
                        let trackWidth: CGFloat = geometry.size.width - reelSize * 0.5
                        let clampedPower: CGFloat = CGFloat(min(1, max(0, power)))
                        let fillWidth: CGFloat = clampedPower * trackWidth
                        let markerOffset: CGFloat = reelSize * 0.5 + fillWidth - 9

                        ZStack(alignment: .leading) {
                            // Back layer / track — fixed width, always fully visible.
                            Capsule()
                                .fill(Self.darkEnd)
                                .overlay(Capsule().stroke(.white, lineWidth: 2))
                                .frame(width: trackWidth, height: barHeight)
                                .padding(.leading, reelSize * 0.5)

                            // Fill — a track-width gradient clipped to the current fill width, so
                            // a given power value reads the same color whether the bar is nearly
                            // empty or nearly full.
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .yellow, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: trackWidth, height: barHeight)
                                .frame(width: fillWidth, alignment: .leading)
                                .clipped()
                                .padding(.leading, reelSize * 0.5)

                            // Power indicator — the reference has none (a static example), but
                            // the bar is meaningless without one live, so a marker is kept,
                            // riding the fill's leading edge.
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

                    HStack {
                        Text(String(format: "Holding %.1fs", holdDuration))
                        Spacer()
                        if let castSolution, phase == .release || phase == .followThrough {
                            Text(String(format: "Power %.2f \u{2022} Distance %.1f m", castSolution.power, castSolution.distance))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
