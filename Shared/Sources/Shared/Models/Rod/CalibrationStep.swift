//
//  CalibrationStep.swift
//  Shared
//

import Foundation

/// The four-step motion-calibration sequence a player walks through before their first cast:
/// capture a natural idle pose, a cast gesture, a reel gesture, then done. Owned by Rod
/// (`RodViewModel.calibrateMotion()` advances it) but transmitted via `RodState` (ADR-064) so
/// World can render live calibration guidance — per `GAMEPLAY_ARCHITECTURE_V1.md`, "Calibration
/// instructions appear entirely in World," a design intent flagged as an open gap since ADR-029.
public enum CalibrationStep: String, Codable, Sendable, Equatable {
    case idle
    case cast
    case reel
    case complete
}
