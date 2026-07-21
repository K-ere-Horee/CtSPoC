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
/// No session-control button here (ADR-038): the session start/end boundary is owned entirely by
/// Rod's own "Start Fishing"/"End Fishing" button — this screen only reflects status. Leaving is
/// driven by `WorldViewModel` reacting to `RodState.isFishing` flipping true, not by anything
/// tapped here. The controls this screen does own — "Forget Device" (device pairing) and "Reset
/// Progress" (tier-unlock progression) — are both unrelated to the fishing session boundary.
///
/// **Visual design (ADR-081).** Restyled from a plain black screen to a full-bleed background
/// photo (`main_menu_bg`) and logo mark (`logo_cts`), with a "stacked rectangle" button style —
/// a cream card with a dark border sitting atop a second, darker rectangle peeking out behind it
/// — matching a supplied reference design. Both images are loose bundled resources, loaded via the
/// shared `bundleImage(_:)` (see `BundleImage.swift` for why the plain `Image("name")` initializer
/// isn't used here).
///
/// **Credits (ADR-087).** Ported from the `feat/ui-slice` branch's `CreditsView` — ownership of
/// showing/dismissing it is purely local `@State` here (a full-screen `.overlay`, not a new
/// `WorldViewModel.Screen` case), since Credits has no bearing on session/gameplay state, unlike
/// every case that enum already models.
struct MainMenuView: View {
    let connectionState: ConnectionState
    let pairedDeviceName: String?
    let hasPairedDevice: Bool
    let calibrationStep: CalibrationStep
    let onForgetDevice: () -> Void
    let onResetProgression: () -> Void
    let onRetryConnection: () -> Void
    let onShowOnboarding: () -> Void

    @State private var isShowingCredits = false

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
            backgroundImage

            VStack(spacing: 22) {
                Spacer(minLength: 32)

                bundleImage("logo_cts")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 360)
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 4)

                Spacer()

                // Calibration guidance takes over this whole status area once Rod is connected
                // but not yet (re)calibrated (ADR-064) — recalibration can now happen at any point
                // after the very first pass too (relaxed to `HookPhase == .idle`, not gated to
                // "before ever pressing Start Fishing"), so a returning player recalibrating from
                // here sees the exact same live, step-reactive guidance.
                statusPanel

                // ADR-061: a player-facing recovery button for the Rod<->World BLE link, reported
                // to occasionally wedge itself into a state that never reconnects on its own —
                // previously only fixable by force-quitting and relaunching World. Shown only
                // while not already connected; retrying a healthy link would just interrupt it.
                if !isRodReady {
                    Button("Retry Connection", action: onRetryConnection)
                        .buttonStyle(StackedMenuButtonStyle(isProminent: true))
                }

                VStack(spacing: 14) {
                    // ADR-064: lets a returning player revisit the intro/objective/levels pages
                    // on demand — the automatic first-launch showing (`WorldViewModel.init`) only
                    // ever happens once.
                    // Secondary when "Retry Connection" is already the prominent action above;
                    // promoted to the prominent style itself once connected, since it's then the
                    // only actionable button left on this screen.
                    Button("How to Play", action: onShowOnboarding)
                        .buttonStyle(StackedMenuButtonStyle(isProminent: isRodReady))
                    Button("Credits") { isShowingCredits = true }
                        .buttonStyle(StackedMenuButtonStyle(isProminent: false))
                    pairedDeviceRow
                    Button("Reset Progress", role: .destructive, action: onResetProgression)
                        .font(.caption.bold())
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.85))
                }
                .padding(.bottom, 56)
            }
            .padding(.horizontal, 32)

            if isShowingCredits {
                CreditsView(onBack: { isShowingCredits = false })
            }
        }
    }

    /// Full-bleed background photo, darkened toward the bottom so the status panel and buttons —
    /// both sitting over the busy lower half of the reference photo — stay legible regardless of
    /// what's underneath, matching the reference design's naturally darker waterline.
    private var backgroundImage: some View {
        ZStack {
            bundleImage("main_menu_bg")
                .resizable()
                .scaledToFill()

            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var statusPanel: some View {
        Group {
            if isRodReady, calibrationStep != .complete {
                CalibrationGuidanceView(step: calibrationStep)
            } else {
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
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.38))
        )
    }

    /// Shows which Rod this Mac is paired with (see `PairedDeviceStore`/ADR-043), and a way to
    /// clear that pairing to pair with a different phone — device pairing is unrelated to the
    /// fishing session boundary, so it lives here rather than gated behind `isRodReady`.
    @ViewBuilder
    private var pairedDeviceRow: some View {
        if hasPairedDevice {
            VStack(spacing: 4) {
                Text("Paired with \(pairedDeviceName ?? "Rod")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                Button("Forget Device", role: .destructive, action: onForgetDevice)
                    .font(.caption.bold())
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.85))
            }
        }
    }
}

/// The "stacked rectangle" button look from the reference design (ADR-081): a cream, dark-bordered
/// card with a second, darker rectangle offset behind/below it, reading as two stacked cards
/// rather than a flat button. `isProminent` scales text/padding for a primary vs. secondary role
/// (matching the reference's larger "Start Fishing" vs. smaller "Credits") without changing the
/// stacked-card treatment itself. Pressing narrows the offset between the two rectangles, reading
/// as the top card physically pressing down onto its stack.
private struct StackedMenuButtonStyle: ButtonStyle {
    var isProminent: Bool

    private static let cream = Color(red: 0.96, green: 0.92, blue: 0.84)
    private static let ink = Color(red: 0.16, green: 0.12, blue: 0.09)

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: isProminent ? 20 : 17, weight: .heavy, design: .rounded))
            .foregroundStyle(Self.ink)
            .padding(.horizontal, isProminent ? 36 : 28)
            .padding(.vertical, isProminent ? 16 : 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Self.ink)
                        .offset(y: pressed ? 2 : 5)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Self.cream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Self.ink, lineWidth: 2.5)
                        )
                        .offset(y: pressed ? 3 : 0)
                }
            )
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}
