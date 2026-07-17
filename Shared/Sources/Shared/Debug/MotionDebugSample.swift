//
//  MotionDebugSample.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 17/07/26.
//

import Foundation

public struct MotionDebugSample: Sendable {

    // MARK: Raw Motion

    public let input: RodMotionInput

    // MARK: Interpreter

    public let interpretation: RodMotionInterpretation

    // MARK: Decision

    public let decision: MotionDebugDecision

    public init(
        input: RodMotionInput,
        interpretation: RodMotionInterpretation,
        decision: MotionDebugDecision
    ) {
        self.input = input
        self.interpretation = interpretation
        self.decision = decision
    }
}
