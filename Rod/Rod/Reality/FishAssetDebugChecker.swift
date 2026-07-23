//
//  FishAssetDebugChecker.swift
//  Rod
//
//  Debug-only tooling (ADR-127) that loads every `FishCatalog` preview asset
//  once and reports pass/fail plus animation count, so a bad/missing
//  `.usdz` surfaces in "Developer Details" instead of only at AR-preview
//  time. Scoped to Rod/Rod/Reality/ per the ADR-127 RealityKit exception;
//  `ContentView` only sees the Foundation-only result type below.
//

import Foundation
import RealityKit
import Shared

#if DEBUG
struct FishAssetCheckResult: Identifiable {
    let id: String
    let name: String
    let passed: Bool
    let animationCount: Int
    let errorDescription: String?
}

@MainActor
enum FishAssetDebugChecker {
    /// Attempts to load every species' `previewAssetName` via
    /// `Entity(named:)` and reports the outcome. Never throws; failures are
    /// captured per-species so one bad asset doesn't stop the rest.
    static func verifyAll() async -> [FishAssetCheckResult] {
        var results: [FishAssetCheckResult] = []
        for species in FishCatalog.all {
            guard let assetName = species.previewAssetName else {
                results.append(
                    FishAssetCheckResult(
                        id: species.id,
                        name: species.name,
                        passed: false,
                        animationCount: 0,
                        errorDescription: "No previewAssetName configured"
                    )
                )
                continue
            }

            do {
                let entity = try await Entity(named: assetName)
                results.append(
                    FishAssetCheckResult(
                        id: species.id,
                        name: species.name,
                        passed: true,
                        animationCount: entity.availableAnimations.count,
                        errorDescription: nil
                    )
                )
            } catch {
                results.append(
                    FishAssetCheckResult(
                        id: species.id,
                        name: species.name,
                        passed: false,
                        animationCount: 0,
                        errorDescription: error.localizedDescription
                    )
                )
            }
        }
        return results
    }
}
#endif
