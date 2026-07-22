//
//  LastCatchStatBoxView.swift
//  World
//

import SwiftUI

/// Small floating stats card summarizing the most recent catch attempt. ADR-100: shares the same
/// dark-rounded-rectangle + white border visual language as `CastMeterView`'s track,
/// `LineTensionView`'s bar, and `FishCounterBadgeView`'s pill, so every HUD element reads as one
/// consistent design system rather than the default `GroupBox` chrome it replaces. Placed
/// top-trailing in `ContentView`, mirroring `fpsIndicator`'s top-leading placement.
struct LastCatchStatBoxView: View {
    let result: FishCatchResult?

    private static let panelColor = Color(red: 0.16, green: 0.12, blue: 0.09)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LAST CATCH")
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.6))

            if let result {
                Text(result.outcome.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(result.outcome == .caught ? .green : .secondary)
                Text(String(format: "%@ \u{2022} %.1f kg \u{2022} %.0f cm", result.speciesName, result.weight, result.length))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                Text("No catch attempts yet")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(10)
        .frame(minWidth: 150, alignment: .leading)
        .background(Self.panelColor, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white, lineWidth: 2))
    }
}
