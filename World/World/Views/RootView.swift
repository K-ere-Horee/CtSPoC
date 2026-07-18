//
//  RootView.swift
//  World
//
//  Top-level screen router: Loading -> Main Menu -> Game (or Credits).
//

import SwiftUI

struct RootView: View {
    private enum Screen {
        case loading
        case mainMenu
        case game
        case credits
    }

    @State private var screen: Screen = .loading

    // Shown unconditionally on every "Start Fishing" for now. Gating this to
    // only a player's first session (persisted progress) is future work.
    @State private var showTutorial = false

    var body: some View {
        Group {
            switch screen {
            case .loading:
                LoadingView()
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        screen = .mainMenu
                    }
            case .mainMenu:
                MainMenuView(
                    onStartFishing: {
                        screen = .game
                        showTutorial = true
                    },
                    onCredit: { screen = .credits }
                )
            case .game:
                ZStack {
                    ContentView()
                    if showTutorial {
                        TutorialView(onFinished: { showTutorial = false })
                    }
                }
            case .credits:
                CreditsView(onBack: { screen = .mainMenu })
            }
        }
    }
}
