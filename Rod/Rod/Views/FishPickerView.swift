//
//  FishPickerView.swift
//  Rod
//
//  Horizontal species picker strip for the AR fish preview screen.
//

import Shared
import SwiftUI

struct FishPickerView: View {
    let species: [FishSpecies]
    let selectedSpecies: FishSpecies?
    let onSelect: (FishSpecies) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(species) { fish in
                    let isSelected = fish.id == selectedSpecies?.id
                    Button {
                        onSelect(fish)
                    } label: {
                        Text(fish.name)
                            .font(.subheadline.weight(isSelected ? .bold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? fish.rarity.color.opacity(0.35) : Color(.secondarySystemBackground),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? fish.rarity.color : Color.primary)
                            .overlay(
                                Capsule().strokeBorder(isSelected ? fish.rarity.color : .clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
