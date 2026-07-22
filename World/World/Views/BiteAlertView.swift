//
//  BiteAlertView.swift
//  World
//

import SwiftUI

/// Shown while a bite window is open (ADR-088), before the fish is actually hooked — the visual
/// half of "haptics nya gedein, jadi user tau kalo hook nya lagi digigit ikan," mirroring
/// `LineTensionView`'s own QTE banner (same shrinking-progress-bar treatment) but for the
/// pre-hook attempt instead of a mid-fight prompt.
struct BiteAlertView: View {
    let isActive: Bool
    /// `1.0` right when a bite window opens, ticking down to `0.0` as `FishFightConfig.
    /// biteWindowDuration` elapses. Meaningless while `!isActive`.
    let progress: Float

    var body: some View {
        if isActive {
            VStack(alignment: .leading, spacing: 4) {
                Label("FISH ON! FLICK TO HOOK!", systemImage: "bolt.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule()
                            .fill(.orange)
                            .frame(width: CGFloat(min(1, max(0, progress))) * geometry.size.width)
                    }
                }
                .frame(height: 6)
            }
        }
    }
}
