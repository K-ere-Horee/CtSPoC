//
//  ContentView.swift
//  Rod
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation
import Shared
import SwiftUI

/// The V1 controller surface per `GAMEPLAY_ARCHITECTURE_V1.md`: title,
/// connection status, and exactly three actions. Raw sensor/debug values
/// are development-only and live behind "Developer Details", collapsed by
/// default, rather than in the primary experience.
struct ContentView: View {
    @ObservedObject
    var viewModel: RodViewModel

    @State private var showDeveloperDetails = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 6) {
                    Text("Catch the Scott")
                        .font(.largeTitle.bold())
                    Text(viewModel.connectionState.rawValue.uppercased())
                        .font(.subheadline.bold())
                        .foregroundStyle(viewModel.connectionState == .streaming ? .green : .secondary)
                }

                fishingButton
                    .padding(.horizontal, 32)

                if viewModel.isFishing {
                    startCastingButton
                        .padding(.horizontal, 32)
                }

                if viewModel.calibrationStep != .complete {
                    Text(calibrationInstruction)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                if let lastError = viewModel.lastError {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                if viewModel.hasPairedDevice {
                    pairedDeviceRow
                }

                Spacer()
                
                /*
                DisclosureGroup("Developer Details", isExpanded: $showDeveloperDetails) {
                    developerDetails
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                 */
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.calibrateMotion()
                    } label: {
                        Label(calibrationButtonTitle, systemImage: "scope")
                    }
                    .disabled(!viewModel.hasMotionSample || viewModel.isFishing)
                }
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    /// Standalone, non-debug pairing-recovery affordance (ADR-062) — deliberately separate from
    /// the commented-out Developer Details `DisclosureGroup` below, which predates this and is
    /// left alone per this project's standing precedent of not touching what looks like someone
    /// else's in-progress work. `TransportClient.didSubscribeTo` silently ignores any central
    /// whose identifier doesn't match `PairedCentralStore`'s saved one — the subscription still
    /// succeeds at the BLE protocol level (so World can read `.ready`/`.streaming` as if
    /// everything's fine), but Rod never actually sends it anything. Without this row, a stale
    /// saved pairing (e.g. after World's own "Forget Device" only clears World's side, or after
    /// reinstalling/testing against a different Mac) was permanently unrecoverable from Rod's UI —
    /// `RodViewModel.forgetPairedDevice()` already existed and worked, it simply had no visible
    /// caller. Mirrors World's own `MainMenuView.pairedDeviceRow` for the same recovery action.
    private var pairedDeviceRow: some View {
        VStack(spacing: 4) {
            Text("Paired with \(viewModel.pairedDeviceShortID ?? "Mac")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Forget Paired Mac", role: .destructive) {
                viewModel.forgetPairedDevice()
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.8))
        }
    }

    /// Single button whose label/action swaps with `isFishing`, rather than two always-present
    /// Start/End buttons — matches the player's own framing: "bukan start fishing atau end
    /// fishing [sekaligus], tapi start fishing, terus ketika mancing ada button end fishing" (not
    /// both Start and End Fishing at once, just Start Fishing, then an End Fishing button once
    /// actually fishing).
    @ViewBuilder
    private var fishingButton: some View {
        if viewModel.isFishing {
            Button {
                viewModel.endFishing()
            } label: {
                Label("End Fishing", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        } else {
            Button {
                viewModel.startFishing()
            } label: {
                Label("Start Fishing", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.calibrationStep != .complete)
        }
    }

    /// Arms one cast attempt (see `RodViewModel.startCasting()`/`RodMotionInterpreter`'s own doc
    /// comment) rather than casting always being live off ordinary phone motion. Disabled once
    /// `hookPhase` is neither `.idle` nor `.result` (per `HookPhase.allowsCasting` plus the
    /// ADR-061 exception that also allows arming from `.result`, doubling as World's old
    /// "Continue Fishing" tap) or once already armed, so re-pressing mid-charge does nothing
    /// rather than looking like a second, independent arm.
    private var startCastingButton: some View {
        Button {
            viewModel.startCasting()
        } label: {
            Label(viewModel.isCastingArmed ? "Casting Armed\u{2026}" : "Start Casting", systemImage: "arrow.up.forward")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled((viewModel.hookPhase != .idle && viewModel.hookPhase != .result) || viewModel.isCastingArmed)
    }

    private var developerDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text("Connection").font(.caption.bold()).foregroundStyle(.secondary)
                statusRow("Transport", value: viewModel.connectionState.rawValue)
                statusRow("Nearby Interaction", value: viewModel.spatialStatus.rawValue)
                statusRow("Motion", value: viewModel.motionAvailable ? "available" : "unavailable")
                statusRow("Pose", value: viewModel.isPoseValid ? "valid" : "invalid")
                statusRow("Motion Phase", value: viewModel.motionPhase.rawValue)
                statusRow("Hook Phase", value: viewModel.hookPhase.rawValue)
                statusRow("Fishing", value: viewModel.isFishing ? "active" : "inactive")
                if viewModel.hasPairedDevice {
                    statusRow("Paired Mac", value: viewModel.pairedDeviceShortID ?? "--")
                    Button("Forget Paired Mac", role: .destructive) {
                        viewModel.forgetPairedDevice()
                    }
                    .font(.caption)
                }
            }

            Group {
                Text("Calibration").font(.caption.bold()).foregroundStyle(.secondary)
                statusRow("Step", value: viewModel.calibrationStep.rawValue)
                statusRow("Samples", value: String(viewModel.calibrationSampleCount))
            }

            Group {
                Text("Rod State").font(.caption.bold()).foregroundStyle(.secondary)
                valueRow("Action", value: viewModel.action.rawValue)
                valueRow("Reel Speed", value: format(viewModel.reelSpeed))
                valueRow(
                    "Reel Calibration Range",
                    value: "\(format(viewModel.reelCalibrationRange.min)) - \(format(viewModel.reelCalibrationRange.max)) rad/s"
                )
                valueRow("Distance", value: format(viewModel.rodState.distance, suffix: " m"))
                valueRow("Direction", value: formatDirection(viewModel.rodState))
                valueRow("Pitch", value: format(viewModel.rodState.pitch))
                valueRow("Roll", value: format(viewModel.rodState.roll))
                valueRow("Yaw", value: format(viewModel.rodState.yaw))
                valueRow("Acceleration Z", value: format(viewModel.motionAccelerationZ))
                valueRow("Rotation Rate", value: format(viewModel.motionRotationRate))
                valueRow("Timestamp", value: String(format: "%.3f", viewModel.rodState.timestamp))
            }

            Group {
                Text("Cast/Reel Classifier").font(.caption.bold()).foregroundStyle(.secondary)
                MotionDebugView(recorder: viewModel.debugRecorder)
            }
        }
        .padding(.top, 8)
    }

    private func statusRow(_ title: String, value: String) -> some View {
        LabeledContent(title, value: value.capitalized)
            .font(.caption)
    }

    private func valueRow(_ title: String, value: String) -> some View {
        LabeledContent(title, value: value)
            .font(.caption)
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
