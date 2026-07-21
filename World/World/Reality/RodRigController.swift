//
//  RodRigController.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 17/07/26.
//

import RealityKit
import AppKit
import simd

/// Drives the live bone-driven pose of `rod_main.usdz` and `rod_line.usdz`. Both assets ship
/// as rest-pose-only skeletons (no baked animation) — the bend and line tension are computed
/// here each frame from the streamed `RodState`, per the asset repo's integration notes.
///
/// `jointNames`/`jointTransforms` live on the skinned `ModelEntity` inside each loaded USDZ
/// hierarchy (via `HasModel`), not on the generic container `Entity` that `Entity(named:)`
/// returns for a `SkelRoot` — so the actual skinned mesh is located by a recursive search.
@MainActor
struct RodRigController {

    /// One joint in a skeletal chain: its full joint path (as authored in the USDZ), how much
    /// of the total bend it should carry (0 = rigid, 1 = full amplitude), and its rest-pose
    /// local translation (bone length), read directly from the shipped rig.
    private struct BoneWeight {
        let jointPath: String
        let weight: Float
        let restTranslation: SIMD3<Float>
    }

    // Verified against rod_main.usdz's Skeleton prim: joints + restTransforms.
    private static let rodBones: [BoneWeight] = [
        BoneWeight(jointPath: "Root", weight: 0, restTranslation: .zero),
        BoneWeight(jointPath: "Root/Handle", weight: 0, restTranslation: .zero),
        BoneWeight(jointPath: "Root/Handle/Rod_01", weight: 0.15, restTranslation: [0, 0.55, 0]),
        BoneWeight(jointPath: "Root/Handle/Rod_01/Rod_02", weight: 0.35, restTranslation: [0, 0.5, 0]),
        BoneWeight(jointPath: "Root/Handle/Rod_01/Rod_02/Rod_03", weight: 0.65, restTranslation: [0, 0.5, 0]),
        BoneWeight(jointPath: "Root/Handle/Rod_01/Rod_02/Rod_03/Tip", weight: 1.0, restTranslation: [0, 0.4, 0])
    ]

    // Verified against rod_line.usdz's Skeleton prim.
    private static let lineBones: [BoneWeight] = [
        BoneWeight(jointPath: "Root", weight: 0, restTranslation: .zero),
        BoneWeight(jointPath: "Root/Anchor", weight: 0, restTranslation: .zero),
        BoneWeight(jointPath: "Root/Anchor/Line_01", weight: 0.2, restTranslation: [0, 0.15, 0]),
        BoneWeight(jointPath: "Root/Anchor/Line_01/Line_02", weight: 0.45, restTranslation: [0, 0.6, 0]),
        BoneWeight(jointPath: "Root/Anchor/Line_01/Line_02/Line_03", weight: 0.7, restTranslation: [0, 0.6, 0]),
        BoneWeight(jointPath: "Root/Anchor/Line_01/Line_02/Line_03/Line_04", weight: 1.0, restTranslation: [0, 0.6, 0])
    ]

    private static let tipJointPath = "Root/Handle/Rod_01/Rod_02/Rod_03/Tip"
    private static let handleJointPath = "Root/Handle"

    /// The line's local origin must sit at the Tip bone's TAIL, not its head — world Y=2.2 in
    /// the rod's rest pose (Tip head is at cumulative Y=1.95). Getting this backwards silently
    /// places the line 0.25 m short of the real rod tip (documented mistake in the asset repo).
    private static let tipTailOffset: SIMD3<Float> = [0, 0.25, 0]

    /// `applyBend` sets each joint's *local* rotation in a parent chain (Rod_01 → Rod_02 → Rod_03
    /// → Tip), so per-bone weighted bends compound down the chain: for small-to-moderate angles,
    /// the effective Tip deflection from the bend chain alone is approximately
    /// `pitch * bendPitchScale * (sum of all bone weights)` = `pitch * bendPitchScale * 2.15`
    /// (weights 0.15 + 0.35 + 0.65 + 1.0). That deflection is *on top of* the whole-rig rotation
    /// in `WorldViewModel.updateRodPose()`, which already applies the same raw pitch/roll once via
    /// `controllerEntity.orientation`. The previous scale (0.55) meant the rod tip moved by
    /// roughly 2.2x the actual device tilt — read as wild, exaggerated whipping rather than a
    /// subtle flex. These scales are picked so the bend chain contributes a modest ~18-20%
    /// *additional* deflection beyond the rig's own rotation (0.085 * 2.15 ≈ 0.183), not a
    /// doubling of it.
    private static let bendPitchScale: Float = 0.085
    private static let bendRollScale: Float = 0.035

    /// Hard per-joint clamp (radians) on the bend contribution, independent of the scale above —
    /// a defensive limit so a transient spike in the streamed pitch/roll (e.g. a fast cast motion,
    /// or noisy/uncalibrated input) can't snap any single joint past a physically plausible flex.
    private static let maxBendAnglePerJoint: Float = 0.35

    /// Same local-transform-in-a-parent-chain compounding as the rod's own bend, applies here too:
    /// `Line_01...Line_04`'s weights (0.2 + 0.45 + 0.7 + 1.0 = 2.35) sum across the chain, so the
    /// previous scale (0.5) produced a cumulative curl of ~1.18 rad (~67°) at full slack (tension
    /// 0, i.e. the resting `.idle` hook phase — visible almost all the time, not just mid-cast).
    /// That folded the line back on itself into a sharp zigzag instead of a gentle sag. Scaled down
    /// so full slack now curls by ~0.35 rad (~20°) total — a natural droop, not a fold — with the
    /// same per-joint clamp as a defensive backstop.
    private static let maxLineSag: Float = 0.15
    private static let maxLineSagAnglePerJoint: Float = 0.35

    /// One-pole low-pass factor applied to the raw pitch/roll fed into `applyBend`'s secondary
    /// flex effect (not the primary whole-rig `RodState.orientation`, which per ADR-016 must reach
    /// the renderer uncalibrated-beyond-World's-own-smoothing — this only softens the supplementary
    /// bend visualization layered on top of it, same as `AGENTS.md`'s "Euler fields may remain for
    /// gameplay-relative motion and diagnostics" allowance). Without this, raw per-sample sensor
    /// noise fed straight into a per-frame bend computation reads as the rod alternating between
    /// looking rigid ("diem") and snapping into an odd flex frame-to-frame, rather than a smooth,
    /// continuous bend — the same class of visible jitter this project already fixed once for the
    /// whole-rig rotation itself (see `CHECKPOINT.md`'s "Rod Tingling" entry), just not yet applied
    /// to this secondary effect.
    private static let bendSmoothing: Double = 0.25

    let root: Entity
    /// World-space marker pinned to the Tip joint's head (zero offset, unlike the line's
    /// tail-offset attach point) — used by gameplay to launch the hook from the rod's actual tip
    /// rather than duplicating the skeletal-pin math at the call site.
    let tipEntity: Entity?
    private let rodModel: ModelEntity?
    private let lineModel: ModelEntity?
    /// Placeholder reel visual — `rod_main.usdz` has exactly one mesh (the rod blank itself,
    /// confirmed by inspecting the extracted `.usdc` directly: a single `Mesh` prim with two
    /// material `GeomSubset`s, no separate reel/spool geometry) and no "Reel" joint in its
    /// skeleton. A real modeled reel is a follow-up asset task (per `AGENTS.md`'s asset-repo
    /// convention), not something fixable from this repo alone; this is a simple flattened-sphere
    /// primitive pinned near the handle, matching this project's own established precedent of
    /// placeholder primitives standing in for missing assets (the hook and old rod "arrow" did the
    /// same). It spins while reeling so the reel at least visibly rotates instead of staying static.
    private let reelEntity: Entity?
    private var smoothedBendPitch: Double = 0
    private var smoothedBendRoll: Double = 0

    static func load() async -> RodRigController {
        let root = Entity()
        root.name = "RodRig"

        let rod = try? await Entity(named: "rod_main")
        let line = try? await Entity(named: "rod_line")

        var rodModel: ModelEntity?
        if let rod {
            root.addChild(rod)
            rodModel = findSkinnedModel(in: rod)
        }

        var lineModel: ModelEntity?
        if let line {
            root.addChild(line)
            lineModel = findSkinnedModel(in: line)

            if let rodModel {
                let tipPin = rodModel.pins.set(
                    named: "LineAttachPin",
                    skeletalJointName: tipJointPath,
                    position: tipTailOffset
                )
                line.attach(to: tipPin)
            }
        }

        var tipEntity: Entity?
        if let rodModel {
            let marker = Entity()
            marker.name = "Tip"
            let tipMarkerPin = rodModel.pins.set(
                named: "TipMarkerPin",
                skeletalJointName: tipJointPath,
                position: .zero
            )
            marker.attach(to: tipMarkerPin)
            tipEntity = marker
        }

        var reelEntity: Entity?
        if let rodModel {
            let reelPin = rodModel.pins.set(
                named: "ReelPin",
                skeletalJointName: handleJointPath,
                position: [0.05, 0.08, 0]
            )
            // Flattened sphere (matches the fish/hook's own non-uniform-scale-sphere convention
            // for a shape this SDK has no dedicated primitive for) standing in for a reel spool.
            let reel = ModelEntity(
                mesh: .generateSphere(radius: 0.045),
                materials: [SimpleMaterial(color: .darkGray, isMetallic: true)]
            )
            reel.scale = [1, 0.45, 1]
            reel.attach(to: reelPin)
            reelEntity = reel
        }

        return RodRigController(root: root, tipEntity: tipEntity, rodModel: rodModel, lineModel: lineModel, reelEntity: reelEntity)
    }

    /// Bends Rod_01...Tip with amplitude increasing toward the tip, driven by how far the
    /// device is currently tilted from its calibrated home pose (already relative in RodState).
    /// The line's own root follows automatically via the Tip pin set up in `load()`.
    mutating func applyBend(pitch: Double, roll: Double) {
        smoothedBendPitch += (pitch - smoothedBendPitch) * Self.bendSmoothing
        smoothedBendRoll += (roll - smoothedBendRoll) * Self.bendSmoothing

        guard let rodModel else { return }
        let jointNames = rodModel.jointNames
        guard !jointNames.isEmpty else { return }

        var transforms = rodModel.jointTransforms
        for bone in Self.rodBones {
            let pitchAngle = clampedBendAngle(Float(smoothedBendPitch) * Self.bendPitchScale * bone.weight)
            let rollAngle = clampedBendAngle(Float(smoothedBendRoll) * Self.bendRollScale * bone.weight)
            let bend =
                simd_quatf(angle: pitchAngle, axis: [1, 0, 0]) *
                simd_quatf(angle: rollAngle, axis: [0, 0, 1])
            if let index = jointNames.firstIndex(of: bone.jointPath), index < transforms.count {
                transforms[index] = Transform(rotation: bend, translation: bone.restTranslation)
            }
        }
        rodModel.jointTransforms = transforms
    }

    private func clampedBendAngle(_ angle: Float) -> Float {
        max(-Self.maxBendAnglePerJoint, min(Self.maxBendAnglePerJoint, angle))
    }

    /// Sags Line_01...Line_04 when slack, straightening as tension increases. Independent of
    /// the rod's own bend, per the asset repo's "drive tension independently" guidance.
    ///
    /// The line's root inherits the rod's Tip joint's full *world* orientation (attached via the
    /// pin set up in `load()`), so a fixed local-X sag axis used to rotate along with whatever
    /// roll `applyBend` gave the tip — under combined pitch+roll the line visibly forked away from
    /// the rod's own bend plane instead of drooping toward true down (a known, previously
    /// unaddressed issue — see `CHECKPOINT.md`'s "Asset-Integration Environment" entry's "Known
    /// Remaining Issue"). Countering by the tip's current world orientation before building the
    /// sag rotation keeps the sag pointed at a stable world-frame direction regardless of the rod's
    /// own roll. Not a full physical simulation — each joint counters against the *tip's* world
    /// orientation rather than fully compounding through the line's own preceding joints, which is
    /// a reasonable approximation given each joint's own contribution is small (bounded by
    /// `maxLineSagAnglePerJoint`, ~20°).
    func applyLineTension(_ tension: Float) {
        guard let lineModel else { return }
        let jointNames = lineModel.jointNames
        guard !jointNames.isEmpty else { return }

        let tipWorldOrientation = tipEntity?.orientation(relativeTo: nil) ?? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        let sagAxis = tipWorldOrientation.inverse.act(SIMD3<Float>(1, 0, 0))

        let slack = max(0, min(1, 1 - tension))
        var transforms = lineModel.jointTransforms
        for bone in Self.lineBones {
            let angle = max(
                -Self.maxLineSagAnglePerJoint,
                min(Self.maxLineSagAnglePerJoint, Self.maxLineSag * slack * bone.weight)
            )
            let sag = simd_quatf(angle: angle, axis: sagAxis)
            if let index = jointNames.firstIndex(of: bone.jointPath), index < transforms.count {
                transforms[index] = Transform(rotation: sag, translation: bone.restTranslation)
            }
        }
        lineModel.jointTransforms = transforms
    }

    /// Spins the placeholder reel entity while actively reeling, proportional to reel speed — a
    /// visible cue standing in for a real modeled reel/crank (see `reelEntity`'s own doc comment).
    /// `spinRate` is hand-picked, not measured against any real reel geometry (none exists yet).
    func applyReelSpin(reelSpeed: Float, isReeling: Bool, deltaTime: Float) {
        guard let reelEntity, isReeling else { return }
        let spinRate: Float = 6.0
        reelEntity.orientation = simd_quatf(angle: spinRate * reelSpeed * deltaTime, axis: [0, 1, 0]) * reelEntity.orientation
    }

    private static func findSkinnedModel(in entity: Entity) -> ModelEntity? {
        if let model = entity as? ModelEntity, !model.jointNames.isEmpty {
            return model
        }
        for child in entity.children {
            if let found = findSkinnedModel(in: child) {
                return found
            }
        }
        return nil
    }
}
