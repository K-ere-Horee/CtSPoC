//
//  TransportHost.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation
import MultipeerConnectivity
import Shared

final class TransportHost: NSObject, TransportProtocol {

    enum HostError: Error {
        case noConnectedPeer
    }

    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var isConnected: Bool {
        !session.connectedPeers.isEmpty
    }

    var onMessage: ((NetworkMessage) -> Void)?
    var onStateChange: ((ConnectionState) -> Void)?

    override init() {
        peerID = MCPeerID(displayName: "World-\(ProcessInfo.processInfo.hostName)")
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: SessionConfiguration.serviceType)
        super.init()

        session.delegate = self
        advertiser.delegate = self
        
        print("[HOST] Initialized")
    }

    func connect() async throws {
        print("[HOST] Start advertising")
        advertiser.startAdvertisingPeer()
        onStateChange?(.searching)
    }

    func disconnect() {
        advertiser.stopAdvertisingPeer()
        session.disconnect()
        onStateChange?(.disconnected)
    }

    func send(_ message: NetworkMessage) async throws {
        guard !session.connectedPeers.isEmpty else {
            throw HostError.noConnectedPeer
        }

        let data = try encoder.encode(message)
        try session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension TransportHost: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("[HOST] Invitation from \(peerID.displayName)")
        invitationHandler(true, session)
    }

//    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
//        onStateChange?(.failed)
//    }
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        print("========== ADVERTISER FAILED ==========")
        print(error)
        let nsError = error as NSError
        print(nsError.domain)
        print(nsError.code)
        print(nsError.userInfo)
    }
}

extension TransportHost: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("[HOST] \(peerID.displayName) -> \(state)")
        switch state {
        case .connected:
            onStateChange?(.ready)
        case .connecting:
            onStateChange?(.connecting)
        case .notConnected:
            onStateChange?(.disconnected)
        @unknown default:
            onStateChange?(.failed)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? decoder.decode(NetworkMessage.self, from: data) else { return }
        onMessage?(message)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
