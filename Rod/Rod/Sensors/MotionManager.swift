//
//  MotionManager.swift
//  Rod
//

import CoreMotion

@MainActor
final class MotionManager {

    private let manager = CMMotionManager()

    var onUpdate: ((MotionSample) -> Void)?

    var isAvailable: Bool {
        manager.isDeviceMotionAvailable
    }

    func start() {
        guard manager.isDeviceMotionAvailable else { return }

        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            self?.onUpdate?(MotionSample(
                timestamp: motion.timestamp,
                pitch: motion.attitude.pitch,
                roll: motion.attitude.roll,
                yaw: motion.attitude.yaw,
                accelerationZ: motion.userAcceleration.z,
                rotationRateMagnitude: sqrt(
                    pow(motion.rotationRate.x, 2) +
                    pow(motion.rotationRate.y, 2) +
                    pow(motion.rotationRate.z, 2)
                )
            ))
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

struct MotionSample {
    let timestamp: TimeInterval
    let pitch: Double
    let roll: Double
    let yaw: Double
    let accelerationZ: Double
    let rotationRateMagnitude: Double
}
