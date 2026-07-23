//
//  FishPreviewView.swift
//  Rod
//
//  Standalone "spawn this fish in AR and read about it" screen (ADR-110).
//  Reachable from ContentView's secondary toolbar icon, entirely outside the
//  live Connect->Cast->Catch loop (no active connection/calibration
//  needed) — but scoped to only species actually caught (ADR-111), read
//  from `CaughtSpeciesStore`. A collection/album screen, not a species
//  browser. Presented via `.fullScreenCover`, so dismissal uses
//  `@Environment(\.dismiss)` rather than a passed-in closure.
//
import RealityKit
import Shared
import SwiftUI

struct FishPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FishPreviewViewModel()

    var body: some View {
        ZStack {
            if viewModel.species.isEmpty {
                emptyState
            } else {
                FishPreviewARViewContainer(viewModel: viewModel)
                    .ignoresSafeArea()

                VStack {
                    topBar

                    if !viewModel.isPlaced {
                        placementHint
                    }

                    if let loadError = viewModel.loadError {
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.red.opacity(0.85), in: Capsule())
                            .padding(.top, 8)
                    }

                    Spacer()

                    if viewModel.isInfoCardVisible, let selectedSpecies = viewModel.selectedSpecies {
                        FishInfoCardView(species: selectedSpecies) {
                            viewModel.isInfoCardVisible = false
                        }
                        .padding(.bottom, 8)
                    }

                    #if DEBUG
                    if viewModel.isPlaced {
                        debugRotationPanel
                            .padding(.bottom, 8)
                    }
                    #endif

                    FishPickerView(
                        species: viewModel.species,
                        selectedSpecies: viewModel.selectedSpecies,
                        onSelect: viewModel.selectSpecies
                    )
                    .padding(.bottom, 12)
                }
            }

            if viewModel.species.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        dismissButton
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .onAppear { viewModel.refreshSpecies() }
        .onDisappear { viewModel.reset() }
    }

    /// Shown when `CaughtSpeciesStore` has nothing yet (ADR-111) — a fresh install, or simply no
    /// catch has synced over from World yet. No AR session is started in this state at all: no
    /// point requesting camera access before there's anything to place.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fish")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No fish caught yet")
                .font(.title3.bold())
            Text("Catch a fish in-game, then come back here to preview it in AR.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.headline)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    #if DEBUG
    /// Temporary on-device orientation tuning tool — see the doc comment on
    /// `FishPreviewViewModel.debugRotationDegrees`. Not meant to ship
    /// long-term; remove once the correct baked-in rotation is confirmed.
    private var debugRotationPanel: some View {
        VStack(spacing: 6) {
            Text("Debug rotation (x, y, z): \(Int(viewModel.debugRotationDegrees.x))°, \(Int(viewModel.debugRotationDegrees.y))°, \(Int(viewModel.debugRotationDegrees.z))°")
                .font(.caption2)
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                axisButtons(label: "X", axis: .x)
                axisButtons(label: "Y", axis: .y)
                axisButtons(label: "Z", axis: .z)

                Button {
                    viewModel.resetDebugRotation()
                } label: {
                    Text("Reset")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.25), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(10)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private func axisButtons(label: String, axis: FishPreviewViewModel.Axis3D) -> some View {
        HStack(spacing: 4) {
            Button {
                viewModel.adjustDebugRotation(axis: axis, by: -90)
            } label: {
                Text("\(label)-90")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2), in: Capsule())
                    .foregroundStyle(.white)
            }
            Button {
                viewModel.adjustDebugRotation(axis: axis, by: 90)
            } label: {
                Text("\(label)+90")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
    }
    #endif

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            if viewModel.isPlaced {
                HStack(spacing: 8) {
                    Button {
                        viewModel.toggleTrueScale()
                    } label: {
                        Image(systemName: viewModel.useTrueScale ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.headline)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    Button {
                        viewModel.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.headline)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var placementHint: some View {
        if let selectedSpecies = viewModel.selectedSpecies {
            Text("Tap a horizontal surface to place \(selectedSpecies.name)")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 16)
        }
    }
}
