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

    public init(
        timestamp: TimeInterval,
        pitch: Double,
        roll: Double,
        yaw: Double,
        rotationRateMagnitude: Double,
        accelerationZ: Double = 0
    ) {
        self.timestamp = timestamp
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.accelerationZ = accelerationZ
        self.rotationRateMagnitude = rotationRateMagnitude
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
    /// Live seconds held in the backswing/charging zone this attempt — transmitted so World can
    /// show the actual charging timer, not just the normalized `castPower` bar (ADR-056).
    public let castHoldDuration: TimeInterval
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
        castHoldDuration: TimeInterval = 0,
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
        self.castHoldDuration = castHoldDuration
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
    /// Timestamp the current cast gesture's backswing/charging hold began — `nil` whenever not
    /// currently holding one. Reset (cleared) whenever a fresh cast gesture begins; feeds both the
    /// live `castPower` meter and, via `CastSnapshot`, `CastResolver`'s final gameplay power.
    private var castHoldStartTimestamp: TimeInterval?
    /// Seconds for one full oscillation of the timing meter (ADR-057) — must match
    /// `CastConfig.oscillationPeriod` so the live meter agrees with `CastResolver`'s authoritative
    /// calculation of the same `backswingHoldDuration` value.
    private let oscillationPeriod: TimeInterval = 3.5
    /// The hold duration a cast actually released at — frozen and replayed during `followThrough`
    /// (mirrors `releasedCastPower`) so the meter shows the final release timing, not a still-
    /// oscillating one.
    private var releasedHoldDuration: TimeInterval = 0

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
        castHoldStartTimestamp = nil
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
        castHoldStartTimestamp = nil
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

        // Cleared whenever not armed, regardless of which classification branch runs below — the
        // single reset point for a fresh cast attempt. Deliberately *not* tied to
        // "classification just changed to .cast" (see `case .cast:` below): a single noisy frame
        // where the pose momentarily reads fractionally closer to idle than cast — real sensor
        // jitter while the player is holding deliberately still to charge — used to flip
        // `previousClassification` to `.idle` for that one frame, so the very next frame's
        // re-entry into `.cast` looked exactly like a fresh attempt and reset the hold timer back
        // to zero. That silently discarded however long the player had already been charging,
        // reading as "the cast never charges no matter how long I hold it."
        if !isCastingArmed {
            castHoldStartTimestamp = nil
        } else {
            // A fresh "Start Casting" press always wins over a still-ticking `followThrough`
            // cooldown from the *previous* attempt. Without this, pressing the button again
            // shortly after a release (well within `profile.castDuration`, since Rod's own
            // cooldown timer is a purely local gesture-recognition detail, independent of the
            // World round-trip that flips `HookPhase` away from `.idle`) would hit the guard below
            // and keep replaying `releasedCastPower`/`releasedHoldDuration` — the *previous* cast's
            // frozen values, which the oscillating meter (ADR-057) can easily have released at or
            // near its peak. That read as "the instant I press Start Casting, power is already
            // maxed," when it was really just the last cast's leftover freeze-frame.
            castEndsAt = input.timestamp
        }

        if input.timestamp < castEndsAt {
            return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: .followThrough, action: .casting, reelSpeed: 0, castPower: releasedCastPower, castHoldDuration: releasedHoldDuration, debug: debug)
        }

        // Once armed, the timing meter runs immediately regardless of the raw pose classification
        // above (ADR-061) — the player shouldn't have to first swing the phone into
        // backswing/cast-pose territory before the meter starts; pressing "Start Casting" alone
        // starts it, and only the flick (forward acceleration, below) matters from then on. Before
        // this, arming while holding the phone in its idle position left `classification == .idle`
        // and the meter pinned at 0 until the player moved the phone closer to `castPose` first,
        // which read as a delay between pressing the button and the meter actually appearing.
        if isCastingArmed {
            let isFreshCastEntry = previousClassification != .cast
            // Only starts the timer if it isn't already running — a momentary classification
            // flicker back to `.idle`/`.reel` and straight back to `.cast` (jitter, not a genuine
            // release-then-recast) must not restart it. It's cleared only by the unarmed-guard
            // above or by `updateProfile(_:)`/`setIdlePose(_:)`'s full resets.
            if castHoldStartTimestamp == nil {
                castHoldStartTimestamp = input.timestamp
            }
            let holdDuration = input.timestamp - castHoldStartTimestamp!

            // Timing-meter curve (ADR-057), matching `CastResolver.resolve(_:)` exactly so the live
            // meter agrees with what a release will actually produce: power oscillates
            // continuously between 0 and 1 for as long as the backswing is held — "meteran naik
            // turun perlahan" — rather than ramping up and capping. The flick (`forwardMotion`
            // below) still triggers the release; it never scales the result (ADR-056), it just
            // locks in whatever this formula reads at that instant.
            let oscillationPhase = holdDuration * 2 * Double.pi / max(oscillationPeriod, 0.001)
            let castPower = Float((1 - cos(oscillationPhase)) / 2)

            let forwardMotion = input.accelerationZ * profile.castAccelerationSign >= profile.castAcceleration
            let backswing = input.accelerationZ * profile.castAccelerationSign < -profile.castAcceleration
            let wasReleased = previousCastPhase == .release
            let phase: RodMotionPhase = backswing
                ? .backswing
                : forwardMotion ? .release : (castPower > 0.05 ? .charging : .forwardSwing)
            previousClassification = .cast
            previousCastPhase = phase
            if forwardMotion && (isFreshCastEntry || !wasReleased) {
                castEndsAt = input.timestamp + profile.castDuration
                releasedCastPower = castPower
                releasedHoldDuration = holdDuration
                return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: .release, action: .casting, reelSpeed: 0, castPower: castPower, castHoldDuration: holdDuration, debug: debug, castSnapshot: snapshot(input: input, orientation: correctedOrientation(currentOrientation), holdDuration: holdDuration))
            }
            return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: phase, action: .idle, reelSpeed: 0, castPower: castPower, castHoldDuration: holdDuration, debug: debug)
        }

        switch classification {
        case .cast:
            // Pose reads closest to `castPose`, but no "Start Casting" press has armed a cast
            // attempt — treat exactly like `.idle` rather than silently starting a hold timer the
            // player never asked for. (`castHoldStartTimestamp` already cleared above.)
            previousClassification = .idle
            previousCastPhase = .idle
            return result(pose: relativePose(from: current), orientation: correctedOrientation(currentOrientation), phase: .idle, action: .idle, reelSpeed: 0, castPower: 0, debug: debug)
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
        castHoldDuration: TimeInterval = 0,
        debug: MotionDebugDecision
        , castSnapshot: CastSnapshot? = nil
    ) -> RodMotionInterpretation {
        RodMotionInterpretation(pose: pose, orientation: orientation, isPoseValid: profile.isComplete, phase: phase, action: action, reelSpeed: reelSpeed, castPower: castPower, castHoldDuration: castHoldDuration, debug: debug, castSnapshot: castSnapshot)
    }

    private func snapshot(input: RodMotionInput, orientation: RodOrientation, holdDuration: TimeInterval) -> CastSnapshot {
        CastSnapshot(
            orientation: orientation,
            timestamp: input.timestamp,
            backswingHoldDuration: holdDuration
        )
    }
}
