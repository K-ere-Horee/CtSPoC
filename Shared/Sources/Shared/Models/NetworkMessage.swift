//
//  NetworkMessage.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation

public enum NetworkMessage: Codable, Sendable {

    case hello(String)
    case motion(MotionPacket)
    case state(RodState)
    case discoveryToken(Data)

}
