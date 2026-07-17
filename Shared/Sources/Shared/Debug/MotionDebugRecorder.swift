//
//  MotionDebugRecorder.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 17/07/26.
//

import Foundation
import Observation

@Observable
public final class MotionDebugRecorder {

    // MARK: - Recording State

    public private(set) var isRecording = false

    public private(set) var sampleCount = 0

    public private(set) var latestSample: MotionDebugSample?

    public private(set) var samples: [MotionDebugSample] = []

    // MARK: - Init

    public init() {}

    // MARK: - Recording

    public func start() {
        samples.removeAll()
        sampleCount = 0
        latestSample = nil
        isRecording = true
    }

    public func stop() {
        isRecording = false
    }

    public func clear() {
        samples.removeAll()
        sampleCount = 0
        latestSample = nil
    }

    public func append(_ sample: MotionDebugSample) {
        guard isRecording else { return }

        samples.append(sample)
        latestSample = sample
        sampleCount = samples.count
    }
}
