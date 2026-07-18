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

            if viewModel.hookPhase == .result, let result = fishFight.lastCatchResult {
                ResultView(result: result) {
                    viewModel.continueFishing()
                }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("World")
                    .font(.title)
                Spacer()
                Text(viewModel.connectionState.rawValue.capitalized)
                    .foregroundStyle(viewModel.connectionState == .streaming ? .green : .secondary)
            }

            RealityView { content in
                let rod = await viewModel.makeSceneEntity()
                content.add(rod)

            } update: { _ in
                viewModel.updateScene()
            }
            .frame(minHeight: 320)

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

            LineTensionView(
                isFighting: fishFight.hasFishOnHook,
                tension: fishFight.lineTension
            )

            GroupBox("Catch Results") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Caught")
                        Spacer()
                        Text("\(fishFight.caughtCount)")
                            .bold()
                    }

                    if let result = fishFight.lastCatchResult {
                        HStack {
                            Text(result.outcome.rawValue)
                                .foregroundStyle(result.outcome == .caught ? .green : .secondary)
                            Spacer()
                            Text(String(format: "%@ \u{2022} %.1f kg \u{2022} %.0f cm", result.speciesName, result.weight, result.length))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    } else {
                        Text("No catch attempts yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            /*
            CastMeterView(
                castSolution: viewModel.rodState.castSolution,
                power: viewModel.rodState.castPower,
                phase: viewModel.rodState.motionPhase
            )
             */

            if let lastError = viewModel.lastError {
                Text(lastError).foregroundStyle(.red)
            }
        }
        .padding(20)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
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
}
