//
//  RodState.swift
//  Shared
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import Foundation

/// Complete controller snapshot. This is the single source of truth sent to World.
public struct RodState: Codable, Sendable, Equatable {

    public let timestamp: TimeInterval
    public let distance: Float?
    public let directionX: Float?
    public let directionY: Float?
    public let directionZ: Float?
    public let pitch: Double
    public let roll: Double
    public let yaw: Double
    public let orientation: RodOrientation
    public let action: RodAction
    public let reelSpeed: Float
    public let castSolution: CastSolution?
    public let motionPhase: RodMotionPhase
    public let castPower: Float
    /// Live seconds held in the current backswing/charging attempt — lets World show the actual
    /// charging timer alongside the normalized `castPower` bar (ADR-056).
    public let castHoldDuration: TimeInterval
    /// Whether the player has pressed "Start Fishing" on Rod. World drives its own Main Menu <->
    /// Playing transition off this field (see ADR-038) instead of a World-side button — Rod is
    /// the sole authority for the session boundary.
    public let isFishing: Bool
    /// Whether the player has pressed "Start Casting" and a cast attempt is currently armed (see
    /// `RodMotionInterpreter.interpret(_:isCastingArmed:)`'s own doc comment). Transmitted
    /// (ADR-061) so World can react to the button press itself, not just the eventual flick —
    /// specifically, auto-dismissing the result screen the instant the player arms a new cast
    /// instead of requiring a separate "Continue Fishing" tap on World first.
    public let isCastingArmed: Bool

    /// Short wire keys (ADR-063). `RodState` is sent on BLE's unreliable `.state` notify path,
    /// which `TransportClient.sendUnreliable(_:)` deliberately never fragments across multiple BLE
    /// packets (a desync risk on a channel with no delivery guarantee) — a message that doesn't
    /// fit one chunk is dropped outright instead. Under the default (property-name) keys, a
    /// `RodState` with a populated `castSolution` — i.e. during and immediately after *every* real
    /// cast — reliably measured 531-542 bytes against the connection's ~512-byte one-chunk budget,
    /// meaning every single cast attempt was silently dropped for its entire `followThrough`
    /// window: Rod computed and released a valid cast, World never received it, nothing ever
    /// logged an error anywhere. Short keys bring that same payload back under 512 bytes with real
    /// margin (~420 bytes measured), independent of whatever future fields get added.
    enum CodingKeys: String, CodingKey {
        case timestamp = "ts"
        case distance = "d"
        case directionX = "dx"
        case directionY = "dy"
        case directionZ = "dz"
        case pitch = "p"
        case roll = "r"
        case yaw = "y"
        case orientation = "o"
        case action = "a"
        case reelSpeed = "rs"
        case castSolution = "cs"
        case motionPhase = "mp"
        case castPower = "cp"
        case castHoldDuration = "chd"
        case isFishing = "f"
        case isCastingArmed = "ca"
    }

    public init(
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        spatial: SpatialState = SpatialState(),
        pitch: Double = 0,
        roll: Double = 0,
        yaw: Double = 0,
        orientation: RodOrientation = .identity,
        action: RodAction = .idle,
        reelSpeed: Float = 0,
        castSolution: CastSolution? = nil,
        motionPhase: RodMotionPhase = .invalid,
        castPower: Float = 0,
        castHoldDuration: TimeInterval = 0,
        isFishing: Bool = false,
        isCastingArmed: Bool = false
    ) {
        self.timestamp = timestamp
        distance = spatial.distance
        directionX = spatial.directionX
        directionY = spatial.directionY
        directionZ = spatial.directionZ
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.orientation = orientation
        self.action = action
        self.reelSpeed = reelSpeed
        self.castSolution = castSolution
        self.motionPhase = motionPhase
        self.castPower = castPower
        self.castHoldDuration = castHoldDuration
        self.isFishing = isFishing
        self.isCastingArmed = isCastingArmed
    }
}
