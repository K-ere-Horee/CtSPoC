//
//  ResultView.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 19/07/26.
//

import SwiftUI

/// Shown when `WorldViewModel.hookPhase == .result`, after a successful catch. Blocks the scene
/// until the player presses "Start Casting" on Rod, which both dismisses this and arms the next
/// attempt (`WorldViewModel.handle(_:)` reacts to `RodState.isCastingArmed`, ADR-061) — there's
/// no dismiss button here, only an instruction label pointing back at Rod.
///
/// No "Return to Menu" here either (ADR-038) — Rod's own "End Fishing" button is now the sole way
/// to end a session (`WorldViewModel` reacts to `RodState.isFishing` going false), so a World-side
/// button making the same call would just get overridden back to `.playing` by the next state
/// update while Rod still thought it was fishing.
struct ResultView: View {
    let result: FishCatchResult

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            card
        }
    }

    private var card: some View {
        VStack(spacing: 14) {
            Text("Catch!")
                .font(.largeTitle.bold())

            Text(result.speciesName)
                .font(.title2)
                .foregroundStyle(.secondary)

            HStack(spacing: 28) {
                stat("Weight", String(format: "%.1f kg", result.weight))
                stat("Length", String(format: "%.0f cm", result.length))
            }
            .padding(.top, 4)

            starsRow

            Label("+\(result.coins)", systemImage: "dollarsign.circle.fill")
                .font(.headline)
                .foregroundStyle(.yellow)

            if result.isNewRecord {
                Text("NEW RECORD")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.yellow.opacity(0.22), in: Capsule())
                    .foregroundStyle(.orange)
            }

            Text("Press \u{201C}Start Casting\u{201D} on Rod to fish again")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 10)
        }
        .padding(28)
        .frame(maxWidth: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 24)
    }

    private var starsRow: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= result.stars ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}
