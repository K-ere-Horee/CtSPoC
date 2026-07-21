//
//  LoadingScreenView.swift
//  World
//

import SwiftUI

/// Shown once, at app launch, while `ContentView`'s `RealityView` asynchronously loads the
/// environment/rod-rig/fish assets (`WorldViewModel.makeSceneEntity()`) — an opaque overlay over
/// the same always-mounted RealityKit scene `MainMenuView`/`OnboardingView` also overlay, so the
/// player never sees an empty/half-built scene flash by before the menu appears (ADR-082).
/// `WorldViewModel` transitions `screen` away from `.loading` itself, from `sceneDidFinishLoading()`
/// — this view has no dismiss logic of its own.
struct LoadingScreenView: View {
    var body: some View {
        ZStack {
            bundleImage("loading_screen")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Requested directly as a flat color layer, not a gradient: "tambahin semacam
            // rectangle layer dengan fills #505277 dengan opacity 40%."
            Color(red: 0x50 / 255, green: 0x52 / 255, blue: 0x77 / 255)
                .opacity(0.4)
                .ignoresSafeArea()

            VStack {
                HStack {
                    bundleImage("logo_cts")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220)
                    Spacer()
                }
                Spacer()
                HStack {
                    Text("Loading...")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
            .padding(32)
        }
    }
}
