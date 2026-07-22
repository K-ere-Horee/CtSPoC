//
//  BiteAlertView.swift
//  World
//

import SwiftUI

/// Shown while a bite window is open (ADR-088), before the fish is actually hooked — the visual
/// half of "haptics nya gedein, jadi user tau kalo hook nya lagi digigit ikan." The only timed
/// prompt left in the fishing loop after ADR-089 removed the mid-fight QTE prompt/reaction window
/// (flicking during an actual fight is now always meaningful, no prompt to show a banner for).
///
/// ADR-103: restyled onto the same dark-brown + white-border card language as the rest of the HUD
/// (`CastMeterView`'s track, `LastCatchStatBoxView`, `ResultView`'s cards) — was bare text over a
/// plain `.quaternary` progress bar. Moved to a center-screen overlay in `ContentView` instead of
/// the bottom-leading stat stack — a QTE-style "flick now!" prompt reads better commanding the
/// middle of the screen than tucked into a corner.
struct BiteAlertView: View {
    let isActive: Bool
    /// `1.0` right when a bite window opens, ticking down to `0.0` as `FishFightConfig.
    /// biteWindowDuration` elapses. Meaningless while `!isActive`.
    let progress: Float

    private static let panelColor = Color(red: 0.16, green: 0.12, blue: 0.09)
    private let trackHeight: CGFloat = 10

    var body: some View {
        if isActive {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    bundleImage("fish_sign")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)

                    Text("FLICK TO HOOK!")
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                }

                GeometryReader { geometry in
                    let fillWidth: CGFloat = CGFloat(min(1, max(0, progress))) * geometry.size.width

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.black.opacity(0.4))
                            .overlay(Capsule().stroke(.white, lineWidth: 2))

                        Capsule()
                            .fill(.orange)
                            .frame(width: fillWidth)
                    }
                }
                .frame(height: trackHeight)
            }
            .padding(20)
            .frame(width: 260)
            .background(Self.panelColor, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white, lineWidth: 2))
            .shadow(radius: 24)
        }
    }
}
