//
//  FishingEvent.swift
//  Shared
//

import Foundation

/// Gameplay outcomes that may be reflected by controller feedback.
public enum FishingEvent: String, Codable, Sendable, Equatable {
    case cast
    case hookSplash
    case reelTick
    case fishBite
    case fishEscaped
    case catchFish
    case lineBreak
}
