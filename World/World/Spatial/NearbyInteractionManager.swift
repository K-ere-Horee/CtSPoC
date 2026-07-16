//
//  NearbyInteractionManager.swift
//  World
//

import Shared

/// World consumes spatial samples produced by Rod.
/// Nearby Interaction itself is unavailable on macOS, so sensing remains on Rod.
final class NearbyInteractionManager {

    var onSpatialUpdate: ((SpatialState) -> Void)?
    var onStatusChange: ((SpatialStatus) -> Void)?

    func start() {
        onStatusChange?(.searching)
    }

    func handle(_ spatialState: SpatialState) {
        onStatusChange?(.updating)
        onSpatialUpdate?(spatialState)
    }
}
