//
//  ProgressionStore.swift
//  World
//

import Foundation
import Shared

/// Tracks cumulative catches per tier and derives the player's current level from them,
/// persisting across launches the same way `FishRecordStore` does. Player-specified thresholds
/// (ADR-037): 10 catches of the current tier's fish unlocks the next one.
///
/// ```text
/// Level 1 (start):        .small catchable
/// -> 10 small caught  ->  Level 2: .medium also catchable
/// -> 10 medium caught ->  Level 3: .big AND .boss (Scott) also catchable
/// ```
///
/// Catching `.big`/`.boss` fish is tracked for future use but doesn't unlock anything further —
/// there's no Level 4 yet.
final class ProgressionStore {

    private static let storageKey = "world.progression"
    private static let thresholds: [FishTier: Int] = [
        .small: 3,
        .medium: 5,
        .big: 10,
        .boss: 1
    ]

    private struct Counts: Codable {
        var small = 0
        var medium = 0
        var big = 0
        var boss = 0
    }

    private var counts: Counts

    init() {
        counts = Self.load()
    }

    var level: Int {
        if counts.big >= Self.thresholds[.big]! { return 4 }
        if counts.medium >= Self.thresholds[.medium]! { return 3 }
        if counts.small >= Self.thresholds[.small]! { return 2 }
        return 1
    }

    var unlockedTiers: Set<FishTier> {
        switch level {
        case 1: return [.small]
        case 2: return [.small, .medium]
        case 3: return [.small, .medium, .big]
        default: return [.small, .medium, .big, .boss]
        }
    }

    /// `(caught, needed)` toward the next unlock — `nil` once every tier is unlocked (level 3),
    /// since there's nothing further to progress toward yet.
    var progressTowardNextLevel: (caught: Int, needed: Int)? {
        switch level {
        case 1: return (counts.small, Self.thresholds[.small]!)
        case 2: return (counts.medium, Self.thresholds[.medium]!)
        case 3: return (counts.big, Self.thresholds[.big]!)
        default:
            return counts.boss >= Self.thresholds[.boss]!
                ? nil
                : (counts.boss, Self.thresholds[.boss]!)
        }
    }

    /// Records a catch of the given tier and returns the level *after* recording it — compare
    /// against the level beforehand to detect a level-up transition.
    @discardableResult
    func recordCatch(tier: FishTier) -> Int {
        switch tier {
        case .small: counts.small += 1
        case .medium: counts.medium += 1
        case .big: counts.big += 1
        case .boss: counts.boss += 1
        }
        save()
        return level
    }

    /// Clears every tier's catch count, dropping `level` back to 1 (only `.small` catchable) —
    /// the player's way to replay the unlock progression from scratch without reinstalling or
    /// clearing app data by hand.
    func reset() {
        counts = Counts()
        save()
    }

    private static func load() -> Counts {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return Counts() }
        return (try? JSONDecoder().decode(Counts.self, from: data)) ?? Counts()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(counts) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
