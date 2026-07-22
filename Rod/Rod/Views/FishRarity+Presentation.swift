//
//  FishRarity+Presentation.swift
//  Rod
//
//  SwiftUI presentation for `FishRarity`. `Color` is UI-framework state and
//  must stay out of Shared (AGENTS.md), so the rarity -> color mapping is a
//  Rod-local extension.
//

import Shared
import SwiftUI

extension FishRarity {
    var color: Color {
        switch self {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}
