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
///
/// ADR-102: restructured to match a supplied reference — a `scott_yeah.png` mascot overlapping the
/// leading edge of a "You caught an **{species}**" message card, a green "Press Start Casting"
/// pill below it (still just a label, not a real button — nothing here is interactive, see above),
/// and the previous catch stats (weight/length/stars/coins/"NEW RECORD") kept in their own card
/// beneath the greeting rather than dropped, per "tambahin aja yang details tadi" (just add the
/// previous details back in). Both cards share the dark-brown + white-border language the rest of
/// the HUD uses (`CastMeterView`'s track, `LastCatchStatBoxView`, `CatchCutsceneView`'s title
/// card, ADR-100/101).
struct ResultView: View {
    let result: FishCatchResult

    private static let panelColor = Color(red: 0.16, green: 0.12, blue: 0.09)
    private static let ctaColor = Color(red: 0.2, green: 0.78, blue: 0.35)

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                greeting
                statsCard

                Text("Press 'Start Casting' on your Rod to fish again!")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Self.panelColor, in: RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white, lineWidth: 2))
            }
            .frame(maxWidth: 380)
        }
    }

    /// Mascot overlapping the leading edge of the message card — `scott_yeah.png` is drawn last
    /// (on top) and offset up/left so it reads as leaning out of the card's corner, matching the
    /// reference rather than sitting flush inside it.
    private var greeting: some View {
        ZStack(alignment: .topLeading) {
            HStack {
                Spacer().frame(width: 100)

                VStack(alignment: .leading, spacing: 8) {
                    Text("You caught an")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("\(result.speciesName)!")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical, 22)
            .padding(.trailing, 20)
            .background(Self.panelColor, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white, lineWidth: 2))

            bundleImage("scott_yeah")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .offset(x: -14, y: -30)
        }
        .shadow(radius: 24)
    }

    private var statsCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 28) {
                stat("Weight", String(format: "%.1f kg", result.weight))
                stat("Length", String(format: "%.0f cm", result.length))
            }

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
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Self.panelColor, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white, lineWidth: 2))
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
            Text(value).font(.headline).foregroundStyle(.white)
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.6))
        }
    }
}

#Preview("Caught") {
    ResultView(
        result: FishCatchResult(
            speciesName: "Rainbow Trout",
            speciesID: "preview_trout",
            weight: 2.8,
            length: 57,
            outcome: .caught,
            stars: 4,
            coins: 120,
            isNewRecord: true
        )
    )
}
