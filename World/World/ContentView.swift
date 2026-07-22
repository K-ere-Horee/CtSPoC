//
//  ContentView.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import RealityKit
import Shared
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: WorldViewModel
    @ObservedObject private var fishFight: FishFightController

    init() {
        let viewModel = WorldViewModel(transport: TransportHost())
        _viewModel = StateObject(wrappedValue: viewModel)
        _fishFight = ObservedObject(wrappedValue: viewModel.fishFight)
    }

    var body: some View {
        ZStack {
            content

            if viewModel.screen == .loading {
                LoadingScreenView()
            }

            if viewModel.screen == .onboarding {
                OnboardingView(onComplete: viewModel.completeOnboarding)
            }

            if viewModel.screen == .mainMenu {
                MainMenuView(
                    connectionState: viewModel.connectionState,
                    pairedDeviceName: viewModel.pairedDeviceName,
                    hasPairedDevice: viewModel.hasPairedDevice,
                    calibrationStep: viewModel.rodState.calibrationStep,
                    onForgetDevice: viewModel.forgetPairedDevice,
                    onResetProgression: viewModel.resetProgression,
                    onRetryConnection: viewModel.retryConnection,
                    onShowOnboarding: viewModel.showOnboarding
                )
            }

            // ADR-064: recalibration is now possible mid-session (any tick `hookPhase == .idle`),
            // not only from the Main Menu before the first "Start Fishing" — this overlay covers
            // that case with the same live guidance `MainMenuView` shows for the first pass.
            if viewModel.screen == .playing, viewModel.hookPhase == .idle,
                viewModel.rodState.calibrationStep != .complete {
                recalibrationOverlay
            }

            if viewModel.screen == .playing, viewModel.isShowingCatchCutscene {
                CatchCutsceneView()
            }

            if viewModel.screen == .playing, viewModel.hookPhase == .result,
                !viewModel.isShowingCatchCutscene, let result = fishFight.lastCatchResult {
                ResultView(result: result)
            }

            if viewModel.screen == .playing, let announcement = fishFight.levelUpAnnouncement {
                LevelUpBannerView(message: announcement) {
                    viewModel.sounds.uiClick()
                    fishFight.dismissLevelUpAnnouncement()
                }
            }

            // ADR-087: ported from `feat/ui-slice`'s `RootView`, which showed this directly over
            // `ContentView()` the instant "Start Fishing" was first pressed — same trigger here
            // (`isShowingTutorial` flips true alongside `screen = .playing` in `handleState(_:)`),
            // just reachable through this screen's own overlay `ZStack` instead of a separate router.
            if viewModel.screen == .playing, viewModel.isShowingTutorial {
                TutorialView(onFinished: viewModel.dismissTutorial)
            }
        }
    }

    /// Scrim + centered card, matching `ResultView`'s own treatment — the player deliberately
    /// chose to recalibrate mid-session, so a focused overlay avoids any ambiguity about game
    /// state during the walkthrough (casting/reeling are already impossible while `hookPhase ==
    /// .idle` requires no fish/hook in flight to begin with).
    private var recalibrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            CalibrationGuidanceView(step: viewModel.rodState.calibrationStep)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 24)
        }
    }

    // ADR-096: the game scene now fills the entire window (no separate HUD bar below it); every
    // HUD element floats as an overlay on top instead. `GeometryReader` supplies screen size so
    // the cast meter can be sized relative to it (~40% width) rather than a fixed constant.
    private var content: some View {
        GeometryReader { geometry in
            ZStack {
                RealityView { content in
                    content.camera = .virtual
                    let rod = await viewModel.makeSceneEntity()
                    content.add(rod)
                    viewModel.attachFrameLoop(to: content)
                    await viewModel.sceneDidFinishLoading()
                }
                .ignoresSafeArea()

                // ADR-105: fps/connection readout moved from top-leading to bottom-leading and
                // restyled onto the same dark-card + white-border language as the rest of the HUD.
                VStack(alignment: .leading) {
                    Spacer()
                    statusBox
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                // ADR-100: last-catch stats, floating top-trailing — mirrors `fpsIndicator`'s
                // top-leading placement, kept visible outside the catch-cutscene fade below since
                // it's a persistent readout rather than routine in-fight HUD.
                VStack(alignment: .trailing) {
                    LastCatchStatBoxView(result: fishFight.lastCatchResult)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding()

                // MARK: - Debug purpose only. Can ignore
                /*
                GroupBox("Controller State") {
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                        row("State", viewModel.connectionState.rawValue)
                        row("Action", viewModel.rodState.action.rawValue)
                        row("Hook", viewModel.hookPhase.rawValue)
                        row("Reel Speed", format(viewModel.rodState.reelSpeed))
                        row("Distance", format(viewModel.rodState.distance, suffix: " m"))
                        row("Last Cast Distance", String(format: "%.2f m", fishFight.lastCastDistance))
                        row("Direction", formatDirection(viewModel.rodState))
                        row("Pitch", format(viewModel.rodState.pitch))
                        row("Roll", format(viewModel.rodState.roll))
                        row("Yaw", format(viewModel.rodState.yaw))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Cast Direction Debug") {
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                        row("Player Facing", formatXZ(viewModel.debugPlayerFacingCoordinate))
                        row("Cast Landed", formatXZ(viewModel.debugCastLandingCoordinate))
                        row("Raw Aim Angle", formatDegrees(viewModel.debugRawAimDegrees))
                        row("Corrected Aim Angle", formatDegrees(viewModel.debugCorrectedAimDegrees))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                */

                // Hidden during the catch cutscene (ADR-048) so the routine gameplay HUD doesn't
                // compete with the dramatic "CATCH!" moment — the RealityView/fps+connection
                // overlay above stays visible, only this HUD fades.
                Group {
                    // Top-center, shrunk to ~40% screen width / 80% original height, with
                    // padding off the top edge so it reads as floating rather than pinned.
                    // ADR-097: `LineTensionView` shares this exact slot — the two are mutually
                    // exclusive in time (charging vs. fighting), so stacking both here reads as
                    // one continuous meter rather than two HUD elements.
                    // ADR-104: extra top padding so the badge/meter stack doesn't sit flush
                    // against the top edge ("biar ga terlalu nempel ke atas").
                    VStack {
                        FishCounterBadgeView(
                            progress: fishFight.progressTowardNextLevel,
                            caughtCount: fishFight.caughtCount
                        )

                        CastMeterView(
                            castSolution: viewModel.rodState.castSolution,
                            power: viewModel.rodState.castPower,
                            phase: viewModel.rodState.motionPhase,
                            holdDuration: viewModel.rodState.castHoldDuration
                        )
                        .frame(width: geometry.size.width * 0.4)
                        .padding(.top, 24)

                        LineTensionView(
                            isFighting: fishFight.hasFishOnHook,
                            tension: fishFight.lineTension
                        )
                        .frame(width: geometry.size.width * 0.4)
                        .padding(.top, 24)

                        Spacer()
                    }
                    .padding(.top, 32)
                    .frame(maxWidth: .infinity)

                    // ADR-103: bite-window "flick to hook" QTE prompt — center screen, since it
                    // needs to command full attention the instant a fish bites.
                    BiteAlertView(
                        isActive: fishFight.isBiteWindowActive,
                        progress: fishFight.biteWindowProgress
                    )

                    // The rest of the HUD keeps roughly its old bottom-of-screen position, now
                    // floating over the fullscreen scene instead of living below it.
                    if let lastError = viewModel.lastError {
                        VStack {
                            Spacer()

                            HStack {
                                Text(lastError)
                                    .foregroundStyle(.red)
                                    .frame(width: geometry.size.width * 0.4, alignment: .leading)

                                Spacer()
                            }
                        }
                        .padding()
                    }
                }
                .opacity(viewModel.isShowingCatchCutscene ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: viewModel.isShowingCatchCutscene)
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private static let panelColor = Color(red: 0.16, green: 0.12, blue: 0.09)

    private var statusBox: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "%.0f FPS", viewModel.fps))
                .font(.caption.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(viewModel.fps >= 50 ? .green : viewModel.fps >= 30 ? .yellow : .red)

            Text(viewModel.connectionState.rawValue.capitalized)
                .font(.caption2)
                .foregroundStyle(viewModel.connectionState == .streaming ? .green : .white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Self.panelColor, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: 2))
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func format(_ value: Float) -> String {
        String(format: "%.3f", value)
    }

    private func format(_ value: Float?, suffix: String = "") -> String {
        guard let value else { return "--" }
        return String(format: "%.3f%@", value, suffix)
    }

    private func formatDirection(_ state: RodState) -> String {
        guard let x = state.directionX, let y = state.directionY, let z = state.directionZ else { return "--" }
        return String(format: "%.2f, %.2f, %.2f", x, y, z)
    }

    private func formatXZ(_ point: SIMD3<Float>?) -> String {
        guard let point else { return "--" }
        return String(format: "(%.2f, %.2f)", point.x, point.z)
    }

    private func formatDegrees(_ degrees: Float?) -> String {
        guard let degrees else { return "--" }
        return String(format: "%.1f°", degrees)
    }
}
