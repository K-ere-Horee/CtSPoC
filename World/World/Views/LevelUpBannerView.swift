//
//  LevelUpBannerView.swift
//  World
//

import SwiftUI

/// Shown when `FishFightController.levelUpAnnouncement` is non-`nil` — a catch just crossed a
/// `ProgressionStore` tier threshold. A toast pinned to the top of the screen, not a blocking
/// modal: it can appear stacked above `ResultView` (the catch that unlocks a tier is still a
/// normal catch too), so it must not compete with or gate that card. Stays until the player
/// dismisses it — no auto-fade timer, so a "Scott has appeared" moment can't be missed by
/// glancing away at the wrong second.
struct LevelUpBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)

                Text(message)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
