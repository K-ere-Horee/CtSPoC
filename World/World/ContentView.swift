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
    @StateObject private var viewModel = WorldViewModel()

    var body: some View {
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

//            #if DEBUG
//            GroupBox("Rod Model Offset") {
//                VStack(spacing: 10) {
//                    orientationSlider("Pitch", value: $viewModel.modelPitch)
//                    orientationSlider("Yaw", value: $viewModel.modelYaw)
//                    orientationSlider("Roll", value: $viewModel.modelRoll)
//                }
//            }
//            #endif

            GroupBox("Controller State") {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    row("State", viewModel.connectionState.rawValue)
                    row("Action", viewModel.rodState.action.rawValue)
                    row("Hook", viewModel.hookPhase.rawValue)
                    row("Reel Speed", format(viewModel.rodState.reelSpeed))
                    row("Distance", format(viewModel.rodState.distance, suffix: " m"))
                    row("Direction", formatDirection(viewModel.rodState))
                    row("Pitch", format(viewModel.rodState.pitch))
                    row("Roll", format(viewModel.rodState.roll))
                    row("Yaw", format(viewModel.rodState.yaw))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

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

    #if DEBUG
    private func orientationSlider(_ title: String, value: Binding<Float>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.0f deg", Double(value.wrappedValue) * 180 / .pi))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: -.pi ... .pi)
                .onChange(of: value.wrappedValue) { _, _ in
                    viewModel.updateModelOrientation()
                }
        }
    }
    #endif

    private func format(_ value: Float?, suffix: String = "") -> String {
        guard let value else { return "--" }
        return String(format: "%.3f%@", value, suffix)
    }

    private func formatDirection(_ state: RodState) -> String {
        guard let x = state.directionX, let y = state.directionY, let z = state.directionZ else { return "--" }
        return String(format: "%.2f, %.2f, %.2f", x, y, z)
    }
}
