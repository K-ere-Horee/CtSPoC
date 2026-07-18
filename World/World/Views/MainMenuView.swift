//
//  MainMenuView.swift
//  World
//
//  Created by Radit on 19/07/26.
//

import SwiftUI

/// The app's landing screen — background art, logo, and the entry points into
/// the game ("Start Fishing") and the credits screen.
struct MainMenuView: View {
    let onStartFishing: () -> Void
    let onCredit: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("LandingImage")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                Theme.overlay
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: geo.size.height * 0.22)
                        .padding(.top, geo.size.height * 0.06)

                    Spacer()

                    VStack(spacing: 20) {
                        menuButton(title: "Start Fishing", action: onStartFishing)
                        menuButton(title: "Credits", action: onCredit)
                    }
                    .padding(.bottom, geo.size.height * 0.1)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func menuButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ShadowedLabel(
                text: title,
                font: .fredokaBold(20),
                color: Theme.menuButtonText,
                shadowColor: Theme.buttonLabelShadow
            )
            .padding(.horizontal, 36)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    Capsule()
                        .fill(Theme.menuButtonEdge)
                        .offset(y: 5)
                    Capsule()
                        .fill(Theme.menuButtonFace)
                    Capsule()
                        .strokeBorder(Theme.menuButtonEdge, lineWidth: 2)
                }
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainMenuView(onStartFishing: {}, onCredit: {})
}
