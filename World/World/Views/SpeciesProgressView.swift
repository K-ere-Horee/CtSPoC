//
//  SpeciesProgressView.swift
//  World
//

import SwiftUI

/// One row's worth of data for `SpeciesProgressView` — kept separate from `FishSpecies` itself so
/// this view doesn't need a `Shared` import just to read a species' own fields, and doesn't need
/// to know about `FishFightController`/`FishRecordStore` to get the live catch count.
struct SpeciesProgressEntry: Identifiable {
    let id: String
    let name: String
    let caught: Int
    let target: Int
}

/// ADR-119: small "fish log" checklist replacing `FishCounterBadgeView`'s single tier-based
/// "1/5 to next tier" badge — requested directly: "progressionnya diganti jangan pake standar Fish
/// A Fish B lagi, tapi sesuai jenis ikan aja... tampilin di sebelah kiri as a little stats gitu,
/// udah nangkep ikan jenis apa berapa, dan target setiap ikan berapa" (change the progression
/// display to stop using the Fish A/Fish B tier standard — go by actual species instead. Show it
/// on the left as a small stats box: which species have been caught, how many, and each fish's
/// target). One row per `FishCatalog.all` entry, in catalog order (small -> medium -> big -> boss),
/// so every species is visible from the start rather than only revealing itself once unlocked —
/// doubles as a preview of what's still ahead. Shares the dark-card + white-border language every
/// other HUD element uses.
struct SpeciesProgressView: View {
    let entries: [SpeciesProgressEntry]

    private static let panelColor = Color(red: 0.16, green: 0.12, blue: 0.09)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FISH LOG")
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.6))

            ForEach(entries) { entry in
                HStack(spacing: 8) {
                    Text(entry.name)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text("\(min(entry.caught, entry.target))/\(entry.target)")
                        .font(.caption.bold())
                        .foregroundStyle(entry.caught >= entry.target ? .green : .white.opacity(0.75))
                }
            }
        }
        .padding(12)
        .frame(width: 190, alignment: .leading)
        .background(Self.panelColor, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white, lineWidth: 2))
    }
}
