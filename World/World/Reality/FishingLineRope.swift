//
//  FishingLineRope.swift
//  World
//

import RealityKit
import AppKit
import simd

/// A verlet-integrated rope standing in for the fishing line (ADR-108). Replaces both the short
/// skeletal `rod_line.usdz` droop *and* the ADR-106/107 single rigid tip->hook box — neither had any
/// dynamics. A chain of points is pinned to the rod tip at index 0; the far end is pinned to the
/// hook while one is cast, or left free to hang under gravity while idle. Each frame: verlet
/// integrate (inertia + gravity), re-pin the endpoints, relax the segment-length constraints a few
/// times, then lay one thin box per segment between consecutive points.
///
/// This is what gives the two requested behaviors: yawing the rod left/right while idle makes the
/// hanging line lag and sway (pendulum inertia), and after a cast the line curves from the tip
/// toward the hook and whips/settles as the hook (or rod) moves, rather than snapping rigidly.
@MainActor
final class FishingLineRope {
    /// Parent of every segment box; added to the scene root by `WorldViewModel`. Kept in world
    /// space (not under the yaw-rotated rig) so both pinned endpoints are real world positions.
    let root: Entity

    private let segmentCount: Int
    private let segmentRestLength: Float
    private var points: [SIMD3<Float>]
    private var previousPoints: [SIMD3<Float>]
    private var segments: [ModelEntity]
    private var initialized = false

    /// Downward pull. Modest — enough to hang the idle line and give a cast line a faint catenary
    /// sag, without the taut far-cast line drooping unrealistically.
    private let gravity: SIMD3<Float> = [0, -5, 0]
    /// Verlet velocity retention per frame (`1` = frictionless, lower = settles faster). Below 1 so
    /// sway damps out instead of oscillating forever.
    private let damping: Float = 0.92
    /// Constraint-relaxation passes per frame. More = stiffer/straighter; fewer = ropier.
    private let iterations = 6

    init(segmentCount: Int = 12, totalRestLength: Float = 2.2, thickness: Float = 0.03) {
        self.segmentCount = segmentCount
        self.segmentRestLength = totalRestLength / Float(segmentCount)
        self.points = Array(repeating: .zero, count: segmentCount + 1)
        self.previousPoints = Array(repeating: .zero, count: segmentCount + 1)

        let root = Entity()
        root.name = "FishingLineRope"

        var segments: [ModelEntity] = []
        segments.reserveCapacity(segmentCount)
        for _ in 0..<segmentCount {
            // Base box is 1 unit tall along +Y; `update` scales Y to each segment's live length.
            // `UnlitMaterial` so the thin line reads consistently against both water and sky.
            let box = ModelEntity(
                mesh: .generateBox(size: [thickness, 1, thickness]),
                materials: [UnlitMaterial(color: .lightGray)]
            )
            root.addChild(box)
            segments.append(box)
        }
        self.segments = segments
        self.root = root
    }

    #if DEBUG
    /// ADR-113 investigation: exposes the rope's own internal endpoint state, so a caller can log
    /// what the rope *itself* holds after `update()` and directly compare it against the values it
    /// was fed — if these disagree, the bug is inside this class (the seed/constraint logic); if
    /// they agree but the rendered rope still looks wrong, the bug is downstream in the per-segment
    /// entity transform assignment or RealityKit's own rendering of it.
    var debugFirstPoint: SIMD3<Float> { points[0] }
    var debugLastPoint: SIMD3<Float> { points[segmentCount] }
    #endif

    /// Shows/hides the whole rope. Hiding also clears `initialized` so the next show re-seeds the
    /// rope straight from the tip to the hook rather than animating in from wherever it was left —
    /// used because the line is only shown once the hook is in the water (ADR-109), so each cast
    /// starts the line fresh at the splash point rather than trailing from the throw.
    func setHidden(_ hidden: Bool) {
        root.isEnabled = !hidden
        if hidden { initialized = false }
    }

    /// Straightens the rope from `tip` to `end` (the hook, or a point hanging below the tip when
    /// idle) with zero velocity — used on the first frame and whenever the endpoints would otherwise
    /// snap from stale positions (e.g. the very first tick, or re-seeding after a long gap).
    private func seed(tip: SIMD3<Float>, end: SIMD3<Float>) {
        for i in 0...segmentCount {
            let t = Float(i) / Float(segmentCount)
            points[i] = tip + (end - tip) * t
            previousPoints[i] = points[i]
        }
        initialized = true
    }

    /// One physics + render step. `hook` is the hook's world position while a hook is out, or `nil`
    /// while idle (the far end then hangs free under gravity).
    func update(tip: SIMD3<Float>, hook: SIMD3<Float>?, deltaTime: Float) {
        let restingEnd = tip + SIMD3<Float>(0, -segmentRestLength * Float(segmentCount), 0)
        if !initialized {
            seed(tip: tip, end: hook ?? restingEnd)
        }

        // Clamp dt so a hitch/long frame can't blow the integrator up.
        let dt = min(max(deltaTime, 1 / 240), 1 / 30)
        let gravityStep = gravity * (dt * dt)
        for i in 0...segmentCount {
            let current = points[i]
            let velocity = (current - previousPoints[i]) * damping
            points[i] = current + velocity + gravityStep
            previousPoints[i] = current
        }

        points[0] = tip
        if let hook { points[segmentCount] = hook }

        for _ in 0..<iterations {
            for i in 0..<segmentCount {
                let delta = points[i + 1] - points[i]
                let distance = simd_length(delta)
                guard distance > 1e-5 else { continue }
                let correction = delta * (0.5 * (distance - segmentRestLength) / distance)
                if i != 0 { points[i] += correction }
                if !(i + 1 == segmentCount && hook != nil) { points[i + 1] -= correction }
            }
            points[0] = tip
            if let hook { points[segmentCount] = hook }
        }

        for i in 0..<segmentCount {
            let a = points[i]
            let b = points[i + 1]
            let delta = b - a
            let length = simd_length(delta)
            guard length > 1e-5 else {
                segments[i].isEnabled = false
                continue
            }
            segments[i].isEnabled = true
            let direction = delta / length
            // Same singularity-free look-rotation as ADR-107: map the box's local +Y onto the
            // segment direction via an explicit orthonormal basis (no `simd_quatf(from:to:)` pole).
            let reference: SIMD3<Float> = abs(direction.y) < 0.99 ? [0, 1, 0] : [1, 0, 0]
            let xAxis = simd_normalize(simd_cross(reference, direction))
            let zAxis = simd_cross(xAxis, direction)
            segments[i].position = (a + b) * 0.5
            segments[i].orientation = simd_quatf(simd_float3x3(columns: (xAxis, direction, zAxis)))
            segments[i].scale = [1, length, 1]
        }
    }
}
