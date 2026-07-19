//
//  MainMenuView.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 19/07/26.
//

import Shared
import SwiftUI

/// World's Main Menu, per `GAMEPLAY_ARCHITECTURE_V1.md`: the entry point before Connect ->
/// Calibration -> Ready. A solid, opaque screen (not a translucent overlay) — the RealityKit
/// scene keeps loading/connecting underneath it, but the player shouldn't see gameplay peeking
/// through a title screen.
///
/// No button here (ADR-038): the session start/end boundary is owned entirely by Rod's own
/// "Start Fishing"/"End Fishing" button — this screen only reflects status. Leaving is driven by
/// `WorldViewModel` reacting to `RodState.isFishing` flipping true, not by anything tapped here.
struct MainMenuView: View {
    let connectionState: ConnectionState

    private var isRodReady: Bool {
        connectionState == .ready || connectionState == .streaming
    }

    private var statusText: String {
        switch connectionState {
        case .idle: "Waiting to connect..."
        case .searching: "Searching for Rod..."
        case .connecting: "Connecting to Rod..."
        case .ready, .streaming: "Press \u{201C}Start Fishing\u{201D} on Rod to play"
        case .disconnected: "Rod disconnected"
        case .failed: "Connection failed"
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Catch the Scott")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("A Two-Device Fishing Experience")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 8) {
                    if isRodReady {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.bottom, 60)
            }
        }
    }
}
