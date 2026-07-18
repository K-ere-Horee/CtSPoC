//
//  FishingEvent.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 15/07/26.
//

import Foundation

/// Gameplay outcomes that may be reflected by controller feedback.
public enum FishingEvent: String, Codable, Sendable, Equatable {
    case cast
    case hookSplash
    case reelTick
    /// A fish is nearby and interested, but has not bitten yet. Rod starts
    /// a slow periodic haptic pulse until the next fishing event arrives.
    case fishInterested
    case fishBite
    case fishEscaped
    case catchFish
    case lineBreak
}
