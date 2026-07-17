//
//  MotionDebugDecision.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 17/07/26.
//

import Foundation

public struct MotionDebugDecision: Sendable, Equatable {

    public let pitchDelta: Double
    public let requiredPitchDelta: Double

    public let forwardAcceleration: Double
    public let requiredForwardAcceleration: Double

    public let cooldownRemaining: TimeInterval

    public let passedPitchCheck: Bool
    public let passedForwardCheck: Bool
    public let passedCooldownCheck: Bool
    public let idleDistance: Double
    public let castDistance: Double
    public let reelDistance: Double
    public let selectedPose: String

    public init(
        pitchDelta: Double,
        requiredPitchDelta: Double,
        forwardAcceleration: Double,
        requiredForwardAcceleration: Double,
        cooldownRemaining: TimeInterval,
        passedPitchCheck: Bool,
        passedForwardCheck: Bool,
        passedCooldownCheck: Bool,
        idleDistance: Double = 0,
        castDistance: Double = 0,
        reelDistance: Double = 0,
        selectedPose: String = "unknown"
    ) {
        self.pitchDelta = pitchDelta
        self.requiredPitchDelta = requiredPitchDelta

        self.forwardAcceleration = forwardAcceleration
        self.requiredForwardAcceleration = requiredForwardAcceleration

        self.cooldownRemaining = cooldownRemaining

        self.passedPitchCheck = passedPitchCheck
        self.passedForwardCheck = passedForwardCheck
        self.passedCooldownCheck = passedCooldownCheck
        self.idleDistance = idleDistance
        self.castDistance = castDistance
        self.reelDistance = reelDistance
        self.selectedPose = selectedPose
    }
}
