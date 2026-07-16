//
//  NearbyInteractionManager.swift
//  Rod
//

import Foundation
import NearbyInteraction
import Shared
import simd

final class NearbyInteractionManager: NSObject {

    private let session = NISession()

    var onSpatialUpdate: ((SpatialState) -> Void)?
    var onStatusChange: ((SpatialStatus) -> Void)?
    var onDiscoveryToken: ((Data) -> Void)?

    override init() {
        super.init()
        session.delegate = self
    }

    func start() {
        guard let token = session.discoveryToken,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            onStatusChange?(.failed)
            return
        }

        onStatusChange?(.searching)
        onDiscoveryToken?(data)
    }

    func handleDiscoveryToken(_ data: Data) {
        guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
            onStatusChange?(.failed)
            return
        }

        session.run(NINearbyPeerConfiguration(peerToken: token))
        onStatusChange?(.ready)
    }
}

extension NearbyInteractionManager: NISessionDelegate {

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }

        let direction = object.direction
        let state = SpatialState(
            distance: object.distance,
            directionX: direction?.x,
            directionY: direction?.y,
            directionZ: direction?.z
        )
        onStatusChange?(.updating)
        onSpatialUpdate?(state)
    }

    func sessionWasSuspended(_ session: NISession) {
        onStatusChange?(.searching)
    }

    func sessionSuspensionEnded(_ session: NISession) {
        start()
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        onStatusChange?(.failed)
    }
}
