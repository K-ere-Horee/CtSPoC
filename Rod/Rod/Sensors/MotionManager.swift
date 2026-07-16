//
//  MotionManager.swift
//  Rod
//

import CoreMotion

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
                pitch: motion.attitude.pitch,
                roll: motion.attitude.roll,
                yaw: motion.attitude.yaw
            ))
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

struct MotionSample {
    let pitch: Double
    let roll: Double
    let yaw: Double
}
