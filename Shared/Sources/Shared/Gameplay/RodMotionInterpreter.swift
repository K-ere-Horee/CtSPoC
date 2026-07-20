//
//  RodMotionInterpreter.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 15/07/26.
//

import Foundation

/// Current device motion. Orientation is intentionally kept separate from interpretation.
public struct RodMotionInput: Sendable, Equatable {
    public let timestamp: TimeInterval
    public let pitch: Double
    public let roll: Double
    public let yaw: Double
    public let accelerationZ: Double
    public let rotationRateMagnitude: Double
    public let rotationRateX: Double
    public let rotationRateY: Double
    public let rotationRateZ: Double

    public init(
        timestamp: TimeInterval,
        pitch: Double,
        roll: Double,
        yaw: Double,
        rotationRateMagnitude: Double,
        accelerationZ: Double = 0,
        rotationRateX: Double = 0,
        rotationRateY: Double = 0,
        rotationRateZ: Double = 0
    ) {
        self.timestamp = timestamp
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.accelerationZ = accelerationZ
        self.rotationRateMagnitude = rotationRateMagnitude
        self.rotationRateX = rotationRateX
        self.rotationRateY = rotationRateY
        self.rotationRateZ = rotationRateZ
    }
}

public enum RodMotionPhase: String, Codable, Sendable, Equatable {
    case invalid
    case idle
    case backswing
    case charging
    case forwardSwing
    case release
    case followThrough
    case casting
    case reeling
}

public struct RodMotionInterpretation: Sendable, Equatable {
    public let pose: RodMotionPose
    public let orientation: RodOrientation
    public let isPoseValid: Bool
    public let phase: RodMotionPhase
    public let action: RodAction
    public let reelSpeed: Float
    public let castPower: Float
    public let debug: MotionDebugDecision
    public let castSnapshot: CastSnapshot?

    public init(
        pose: RodMotionPose,
        orientation: RodOrientation,
        isPoseValid: Bool,
        phase: RodMotionPhase,
        action: RodAction,
        reelSpeed: Float,
        castPower: Float = 0,
        debug: MotionDebugDecision
        , castSnapshot: CastSnapshot? = nil
    ) {
        self.pose = pose
        self.orientation = orientation
        self.isPoseValid = isPoseValid
        self.phase = phase
        self.action = action
        self.reelSpeed = reelSpeed
        self.castPower = castPower
        self.debug = debug
        self.castSnapshot = castSnapshot
    }
}

/// Classifies movement by comparing current orientation to the player's poses.
public final class RodMotionInterpreter {
    public var profile: MotionProfile

    private var previousClassification: Classification = .idle
    private var castEndsAt: TimeInterval = 0
    private var hasIdleReference = false
    private var previousCastPhase: RodMotionPhase = .idle
    private var releasedCastPower: Float = 0
    /// Peak angular distance (radians) from the idle pose reached so far
    /// during the current cast gesture. Reset when a fresh cast gesture
    /// begins; feeds both the live `castPower` meter and, via `CastSnapshot`,
    /// `CastResolver`'s final gameplay power.
    private var backswingPeakDistance: Double = 0
    private let minimumBackswingDistance: Double = 0.12
    private let maximumBackswingDistance: Double = 1.0

    private enum Classification: String {
        case idle
        case cast
        case reel
    }

    public init(profile: MotionProfile = MotionProfile()) {
        self.profile = profile
    }

    public func updateProfile(_ profile: MotionProfile) {
        self.profile = profile
        previousClassification = .idle
        castEndsAt = 0
        previousCastPhase = .idle
        releasedCastPower = 0
        backswingPeakDistance = 0
        hasIdleReference = profile.isComplete
    }

    /// Installs the idle frame immediately so calibration preview and runtime
    /// rendering consume the same corrected orientation.
    public func setIdlePose(_ pose: MotionPose) {
        profile.idlePose = pose
        profile.calibrationReference = RodOrientation.from(pitch: pose.pitch, roll: pose.roll, yaw: pose.yaw)
        hasIdleReference = true
        previousClassification = .idle
        castEndsAt = 0
        previousCastPhase = .idle
        releasedCastPower = 0
        backswingPeakDistance = 0
    }

    /// - Parameter isCastingArmed: Gates whether a pose classified closest to `castPose` is
    ///   actually treated as a cast attempt. When `false`, any such pose is treated exactly like
    ///   `.idle` — no backswing tracking, no charging phase, no cast meter — so ordinary phone
    ///   movement can never accidentally start a charge. The caller (Rod's "Start Casting" button)
    ///   sets this only for the duration of one attempt; it's automatically consumed (the caller
    ///   should disarm) once `RodMotionInterpretation.castSnapshot` comes back non-`nil`, meaning a
    ///   real cast just fired.
    public func interpret(_ input: RodMotionInput, isCastingArmed: Bool) -> RodMotionInterpretation {
        let current = MotionPose(pitch: input.pitch, roll: input.roll, yaw: input.yaw)
        let currentOrientation = RodOrientation.from(pitch: input.pitch, roll: input.roll, yaw: input.yaw)

        guard hasIdleReference else {
            return result(pose: current, orientation: currentOrientation, phase: .invalid, action: .idle, reelSpeed: 0, castPower: 0, debug: emptyDebug)
        }

        guard profile.isComplete else {
            return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: .invalid, action: .idle, reelSpeed: 0, castPower: 0, debug: emptyDebug)
        }

        let distances = distances(from: current)
        let classification = distances.minimum
        let debug = MotionDebugDecision(
            pitchDelta: distances.idle,
            requiredPitchDelta: distances.cast,
            forwardAcceleration: input.accelerationZ,
            requiredForwardAcceleration: profile.castAcceleration,
            cooldownRemaining: max(0, castEndsAt - input.timestamp),
            passedPitchCheck: classification == .cast,
            passedForwardCheck: input.accelerationZ * profile.castAccelerationSign >= profile.castAcceleration,
            passedCooldownCheck: input.timestamp >= castEndsAt,
            idleDistance: distances.idle,
            castDistance: distances.cast,
            reelDistance: distances.reel,
            selectedPose: classification.rawValue
        )

        if input.timestamp < castEndsAt {
            return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: .followThrough, action: .casting, reelSpeed: 0, castPower: releasedCastPower, debug: debug)
        }

        switch classification {
        case .cast where !isCastingArmed:
            // Pose reads closest to `castPose`, but no "Start Casting" press has armed a cast
            // attempt — treat exactly like `.idle` rather than silently tracking a backswing the
            // player never asked for.
            previousClassification = .idle
            previousCastPhase = .idle
            backswingPeakDistance = 0
            return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: .idle, action: .idle, reelSpeed: 0, castPower: 0, debug: debug)
        case .cast:
            let enteredCast = previousClassification != .cast
            if enteredCast {
                backswingPeakDistance = 0
            }
            backswingPeakDistance = max(backswingPeakDistance, distances.idle)

            let distancePower = Float(min(1, max(0, (backswingPeakDistance - minimumBackswingDistance) / max(0.0001, maximumBackswingDistance - minimumBackswingDistance))))
            let flickPower = Float(min(1, max(0, input.rotationRateMagnitude / 5)))
            // How far the backswing traveled sets the base power; a fast
            // flick only adds up to a 30% bonus on top — matches
            // `CastResolver.resolve(_:)`'s blend, so the live meter tracks
            // what the release will actually produce.
            let castPower = distancePower * (0.7 + 0.3 * flickPower)

            let forwardMotion = input.accelerationZ * profile.castAccelerationSign >= profile.castAcceleration
            let backswing = input.accelerationZ * profile.castAccelerationSign < -profile.castAcceleration
            let wasReleased = previousCastPhase == .release
            let phase: RodMotionPhase = backswing
                ? .backswing
                : forwardMotion ? .release : (castPower > 0.05 ? .charging : .forwardSwing)
            previousClassification = classification
            previousCastPhase = phase
            if forwardMotion && (enteredCast || !wasReleased) {
                castEndsAt = input.timestamp + profile.castDuration
                releasedCastPower = castPower
                return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: .release, action: .casting, reelSpeed: 0, castPower: castPower, debug: debug, castSnapshot: snapshot(input: input, orientation: correctedOrientation(currentOrientation)))
            }
            return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: phase, action: .idle, reelSpeed: 0, castPower: castPower, debug: debug)
        case .reel:
            previousClassification = classification
            guard input.rotationRateMagnitude >= profile.reelRotationRate else { break }
            let minRate = profile.reelRotationRate
            let maxRate = max(profile.reelFullRotationRate, minRate + 0.05)
            let speed = Float(min(1, max(0, (input.rotationRateMagnitude - minRate) / (maxRate - minRate))))
            previousCastPhase = .idle
            return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: .reeling, action: .reeling, reelSpeed: speed, castPower: 0, debug: debug)
        case .idle:
            previousClassification = classification
        }

        return result(
            pose: relativePose(from: current),
            orientation: correctedOrientation(currentOrientation),
            phase: classification == .idle ? .idle : .invalid,
            action: .idle,
            reelSpeed: 0,
            castPower: 0,
            debug: debug
        )
    }

    private var emptyDebug: MotionDebugDecision {
        MotionDebugDecision(
            pitchDelta: 0,
            requiredPitchDelta: 0,
            forwardAcceleration: 0,
            requiredForwardAcceleration: 0,
            cooldownRemaining: 0,
            passedPitchCheck: false,
            passedForwardCheck: false,
            passedCooldownCheck: false
        )
    }

    private func distances(from current: MotionPose) -> (idle: Double, cast: Double, reel: Double, minimum: Classification) {
        let idle = distance(current, profile.idlePose)
        let cast = distance(current, profile.castPose)
        let reel = distance(current, profile.reelPose)
        if idle <= cast && idle <= reel { return (idle, cast, reel, .idle) }
        if cast <= reel { return (idle, cast, reel, .cast) }
        return (idle, cast, reel, .reel)
    }

    private func distance(_ lhs: MotionPose, _ rhs: MotionPose) -> Double {
        let pitch = wrapped(lhs.pitch - rhs.pitch)
        let roll = wrapped(lhs.roll - rhs.roll)
        let yaw = wrapped(lhs.yaw - rhs.yaw)
        return sqrt((pitch * pitch) + (roll * roll) + (yaw * yaw))
    }

    private func relativePose(from current: MotionPose) -> MotionPose {
        MotionPose(
            pitch: wrapped(current.pitch - profile.idlePose.pitch),
            roll: wrapped(current.roll - profile.idlePose.roll),
            yaw: wrapped(current.yaw - profile.idlePose.yaw)
        )
    }

    private func correctedOrientation(_ current: RodOrientation) -> RodOrientation {
        profile.calibrationReference.inverted() * current
    }

    private func wrapped(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: .pi * 2)
        if value > .pi { value -= .pi * 2 }
        if value < -.pi { value += .pi * 2 }
        return value
    }

    private func result(
        pose: MotionPose,
        orientation: RodOrientation,
        phase: RodMotionPhase,
        action: RodAction,
        reelSpeed: Float,
        castPower: Float = 0,
        debug: MotionDebugDecision
        , castSnapshot: CastSnapshot? = nil
    ) -> RodMotionInterpretation {
        RodMotionInterpretation(pose: pose, orientation: orientation, isPoseValid: profile.isComplete, phase: phase, action: action, reelSpeed: reelSpeed, castPower: castPower, debug: debug, castSnapshot: castSnapshot)
    }

    private func snapshot(input: RodMotionInput, orientation: RodOrientation) -> CastSnapshot {
        CastSnapshot(
            orientation: orientation,
            angularVelocity: CastVector3(x: Float(input.rotationRateX), y: Float(input.rotationRateY), z: Float(input.rotationRateZ)),
            timestamp: input.timestamp,
            backswingDistance: Float(backswingPeakDistance)
        )
    }
}
