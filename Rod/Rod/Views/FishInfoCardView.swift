//
//  FishInfoCardView.swift
//  Rod
//
//  Info overlay shown after tapping the placed fish in
//  `FishPreviewView`. Mirrors World/World/Views/ResultView.swift's card
//  chrome (`.regularMaterial` rounded rectangle, a `stat()` row helper) so
//  Rod's one gameplay-adjacent card reads consistently with World's.
//

import Shared
import SwiftUI

struct FishInfoCardView: View {
    let species: FishSpecies
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(species.name)
                        .font(.title2.bold())
                    Text(species.scientificName)
                        .font(.subheadline.italic())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            rarityBadge

            Text(species.description)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 28) {
                stat("Weight", weightText)
                stat("Length", lengthText)
            }
            .padding(.top, 4)

            if let attribution = species.attribution {
                Text(attribution)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 24)
    }

    private var rarityBadge: some View {
        Text(species.rarity.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(species.rarity.color.opacity(0.22), in: Capsule())
            .foregroundStyle(species.rarity.color)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var weightText: String {
        String(format: "%.0f–%.0f kg", species.weightRange.min, species.weightRange.max)
    }

    private var lengthText: String {
        String(format: "%.0f–%.0f cm", species.lengthRange.min, species.lengthRange.max)
    }
}
