//
//  ContentView.swift
//  Rod
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation
import Shared
import SwiftUI

struct ContentView: View {
    @ObservedObject
    var viewModel: RodViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    statusRow("Transport", value: viewModel.connectionState.rawValue)
                    statusRow("Nearby Interaction", value: viewModel.spatialStatus.rawValue)
                    statusRow("Motion", value: viewModel.motionAvailable ? "available" : "unavailable")
                    statusRow("Pose", value: viewModel.isPoseValid ? "valid" : "invalid")
                    statusRow("Motion Phase", value: viewModel.motionPhase.rawValue)
                    statusRow("Hook Phase", value: viewModel.hookPhase.rawValue)
                }

                Section("Motion Calibration") {
                    Text(calibrationInstruction)
                        .font(.caption)
                    statusRow("Step", value: viewModel.calibrationStep.rawValue)
                    if viewModel.calibrationStep != .complete {
                        statusRow("Samples", value: String(viewModel.calibrationSampleCount))
                        Button { viewModel.calibrateMotion() } label: {
                            Label(calibrationButtonTitle, systemImage: "scope")
                        }
                        .disabled(!viewModel.hasMotionSample)
                    } else {
                        Button { viewModel.calibrateMotion() } label: {
                            Label("Recalibrate Motion", systemImage: "arrow.clockwise")
                        }
                    }
                }

                Section("Rod State") {
                    valueRow("Action", value: viewModel.action.rawValue)
                    valueRow("Reel Speed", value: format(viewModel.reelSpeed))
                    valueRow("Distance", value: format(viewModel.rodState.distance, suffix: " m"))
                    valueRow("Direction", value: formatDirection(viewModel.rodState))
                    valueRow("Pitch", value: format(viewModel.rodState.pitch))
                    valueRow("Roll", value: format(viewModel.rodState.roll))
                    valueRow("Yaw", value: format(viewModel.rodState.yaw))
                    valueRow("Acceleration Z", value: format(viewModel.motionAccelerationZ))
                    valueRow("Rotation Rate", value: format(viewModel.motionRotationRate))
                    valueRow("Timestamp", value: String(format: "%.3f", viewModel.rodState.timestamp))
                }

                /*
                #if DEBUG
                Section("Motion Debug") {
                    MotionDebugView(recorder: viewModel.debugRecorder)
                }
                #endif
                 */

                if let lastError = viewModel.lastError {
                    Section("Error") { Text(lastError).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Rod Controller")
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private func statusRow(_ title: String, value: String) -> some View {
        LabeledContent(title, value: value.capitalized)
    }

    private func valueRow(_ title: String, value: String) -> some View {
        LabeledContent(title, value: value)
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

    private var calibrationInstruction: String {
        switch viewModel.calibrationStep {
        case .idle: return "Hold the rod naturally for a few seconds, then capture your idle pose."
        case .cast: return "Perform one natural forward cast, then capture it."
        case .reel: return "Reel naturally for a moment, then capture it."
        case .complete: return "Motion calibration complete."
        }
    }

    private var calibrationButtonTitle: String {
        switch viewModel.calibrationStep {
        case .idle: return "Capture Idle Pose"
        case .cast: return "Capture Cast Gesture"
        case .reel: return "Capture Reel Gesture"
        case .complete: return "Recalibrate Motion"
        }
    }
}
