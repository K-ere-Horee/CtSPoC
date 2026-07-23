//
//  FishPreviewViewModel.swift
//  Rod
//
//  Drives the standalone "spawn this fish in AR and read about it" screen
//  (ADR-121). Intentionally independent of `RodViewModel` and the live
//  Connect->Cast->Catch loop (previewing doesn't require an active
//  connection or calibration) — but `species` (ADR-122) is *not*
//  independent of catch history: only species the player has actually
//  caught are previewable, read from `CaughtSpeciesStore`'s local copy of
//  World's own catch record (World has no direct in-memory link to Rod, so
//  this arrives over transport as `NetworkMessage.caughtSpecies`, not read
//  live). This is a collection/album screen, not a species browser.
//

import ARKit
import Combine
import RealityKit
import Shared
import SwiftUI

@MainActor
final class FishPreviewViewModel: ObservableObject {

    /// Only species the player has actually caught (ADR-122), filtered from the Shared catalog by
    /// `CaughtSpeciesStore`'s locally-persisted copy of World's catch record. Empty until the
    /// first catch has synced over — `FishPreviewView` shows a distinct empty state in that case
    /// rather than treating it as a loading/error condition.
    @Published private(set) var species: [FishSpecies] = []

    @Published private(set) var selectedSpecies: FishSpecies?
    @Published var isInfoCardVisible = false
    @Published private(set) var isPlaced = false
    @Published var loadError: String?
    /// `true` (default): render each species at its real, biologically
    /// accurate length from `FishSpecies.lengthRange`. `false`: cap the
    /// displayed length so large species still fit a typical indoor room.
    /// Either way the scale is computed from the *loaded entity's own
    /// measured bounding box*, not trusted from the source asset's export
    /// units — some Preview exports (e.g. sailfish, sourced through a
    /// different FBX/Sketchfab import chain than the Blender-native fish)
    /// do not actually honor the stage's declared `metersPerUnit = 1`, so
    /// trusting native scale blindly would render them wildly wrong-sized.
    @Published var useTrueScale = true

    /// `#if DEBUG`-only live orientation correction, in degrees per axis,
    /// applied on top of whatever rotation is already baked into the
    /// `.usdz`'s `SkelRoot` transform. Exists because repeatedly guessing a
    /// baked-in fix and round-tripping through export/rebuild/redeploy to
    /// test each guess on-device proved too slow and unreliable (four
    /// rounds were needed just for the dorsal-ventral axis, and RealityKit's
    /// actual applied rotation direction did not match textbook right-hand-
    /// rule math derived from the source USD). This lets the correct value
    /// be found interactively on-device in seconds instead. Once a value is
    /// confirmed to look right, it should be reported back and baked in
    /// permanently (either into the asset or as a fixed Swift-side
    /// constant) — this control is not meant to ship long-term.
    #if DEBUG
    @Published private(set) var debugRotationDegrees: SIMD3<Float> = .zero
    #endif

    private var anchorEntity: AnchorEntity?
    private var fishEntity: Entity?
    private weak var arView: ARView?

    /// Cap applied to the displayed length only when `useTrueScale == false`.
    private static let compactDisplayLengthMeters: Float = 1.1

    private let caughtSpeciesStore = CaughtSpeciesStore()

    init() {
        refreshSpecies()
    }

    /// Re-reads `CaughtSpeciesStore` and rebuilds `species`/`selectedSpecies` (ADR-122). Called on
    /// `init()` and from `FishPreviewView`'s `.onAppear`, in case a catch synced over from World
    /// while this screen wasn't open — `CaughtSpeciesStore` is a thin, publisher-less UserDefaults
    /// wrapper (mirrors `FishRecordStore`'s own design), so it can't push updates on its own.
    /// Keeps the current selection if it's still in the (possibly changed) caught set; otherwise
    /// falls back to the first available species, or `nil` if none have been caught yet.
    ///
    /// `#if DEBUG`: shows every `FishCatalog` species regardless of catch history, so an export/
    /// orientation audit doesn't require actually catching all 8 fish first (ADR-124's on-device
    /// round). Never reaches a release build — same temporary-tool convention as
    /// `debugRotationDegrees` below.
    func refreshSpecies() {
        #if DEBUG
        species = FishCatalog.all
        #else
        let caughtIDs = caughtSpeciesStore.caughtSpeciesIDs
        species = FishCatalog.all.filter { caughtIDs.contains($0.id) }
        #endif
        if let selectedSpecies, species.contains(where: { $0.id == selectedSpecies.id }) {
            return
        }
        selectedSpecies = species.first
    }

    /// Places the currently selected species at a raycast hit transform and
    /// begins loading its preview asset. Called once, on the first tap,
    /// from `FishPreviewARViewContainer.Coordinator`.
    func placeFish(at transform: simd_float4x4, in arView: ARView) {
        guard !isPlaced, selectedSpecies != nil else { return }
        self.arView = arView

        let anchor = AnchorEntity(world: transform)
        arView.scene.addAnchor(anchor)
        addFillLight(to: anchor)
        anchorEntity = anchor
        isPlaced = true

        Task { await loadAndAttachFish() }
    }

    /// A real `UsdPreviewSurface` material (unlike RealityKit's flat
    /// fallback material shown before the export repair) is fully
    /// light-dependent. Real rooms are often too dim, and ARKit's automatic
    /// environment-texturing IBL probe takes time/camera movement to build
    /// up, so a freshly placed fish can render near-black without an
    /// explicit light guaranteeing a lit-enough result regardless of the
    /// surrounding room or how long the AR session has been running.
    private func addFillLight(to anchor: AnchorEntity) {
        let sun = Entity()
        var directional = DirectionalLightComponent()
        directional.color = .white
        directional.intensity = 1500
        sun.components.set(directional)
        sun.position = SIMD3<Float>(0, 1.2, 0.6)
        sun.look(at: .zero, from: sun.position, relativeTo: anchor)
        anchor.addChild(sun)

        let fill = Entity()
        var point = PointLightComponent()
        point.color = .white
        point.intensity = 800
        point.attenuationRadius = 5
        fill.components.set(point)
        fill.position = SIMD3<Float>(0, 0.6, -0.4)
        anchor.addChild(fill)
    }

    /// Switches the previewed species. If a fish is already placed, reloads
    /// the new species' asset in place of the old one.
    func selectSpecies(_ newSpecies: FishSpecies) {
        guard newSpecies.id != selectedSpecies?.id else { return }
        selectedSpecies = newSpecies
        isInfoCardVisible = false
        guard isPlaced else { return }
        Task { await loadAndAttachFish() }
    }

    /// Called by the coordinator's hit-test when a tap lands on an entity
    /// that's part of the placed fish.
    func handleTap(on entity: Entity) {
        guard let fishEntity, isDescendant(entity, of: fishEntity) else { return }
        isInfoCardVisible = true
    }

    func toggleTrueScale() {
        useTrueScale.toggle()
        guard isPlaced else { return }
        Task { await loadAndAttachFish() }
    }

    /// Removes the placed fish and resets the screen back to "tap to place".
    func reset() {
        if let anchorEntity {
            arView?.scene.removeAnchor(anchorEntity)
        }
        anchorEntity = nil
        fishEntity = nil
        arView = nil
        isPlaced = false
        isInfoCardVisible = false
        loadError = nil
    }

    private func loadAndAttachFish() async {
        guard let anchorEntity, let selectedSpecies, let assetName = selectedSpecies.previewAssetName else {
            loadError = selectedSpecies.map { "No preview model available for \($0.name)." }
            return
        }

        anchorEntity.children.removeAll()
        fishEntity = nil

        do {
            let entity = try await Entity(named: assetName)
            entity.generateCollisionShapes(recursive: true)
            entity.components.set(InputTargetComponent())

            let scale = realisticScale(for: entity, species: selectedSpecies)
            entity.scale = SIMD3<Float>(repeating: scale)

            if let animation = entity.availableAnimations.first {
                entity.playAnimation(animation.repeat())
            }

            anchorEntity.addChild(entity)
            fishEntity = entity
            loadError = nil
            #if DEBUG
            applyDebugRotation()
            #endif
        } catch {
            loadError = "Couldn't load \(selectedSpecies.name): \(error.localizedDescription)"
        }
    }

    #if DEBUG
    /// Nudges the live correction by 90° on one axis and re-applies it
    /// immediately to the currently loaded entity — no reload needed.
    func adjustDebugRotation(axis: Axis3D, by degreesDelta: Float) {
        switch axis {
        case .x: debugRotationDegrees.x += degreesDelta
        case .y: debugRotationDegrees.y += degreesDelta
        case .z: debugRotationDegrees.z += degreesDelta
        }
        applyDebugRotation()
    }

    func resetDebugRotation() {
        debugRotationDegrees = .zero
        applyDebugRotation()
    }

    private func applyDebugRotation() {
        let radians = debugRotationDegrees * (Float.pi / 180)
        let qx = simd_quatf(angle: radians.x, axis: SIMD3<Float>(1, 0, 0))
        let qy = simd_quatf(angle: radians.y, axis: SIMD3<Float>(0, 1, 0))
        let qz = simd_quatf(angle: radians.z, axis: SIMD3<Float>(0, 0, 1))
        fishEntity?.orientation = qz * qy * qx
    }

    enum Axis3D {
        case x, y, z
    }
    #endif

    /// Computes a scale factor so the *rendered* fish matches a real,
    /// biologically accurate length, regardless of what unit convention the
    /// source `.usdz` actually used. Measures the freshly loaded entity's
    /// own bounding box rather than trusting the stage's declared
    /// `metersPerUnit`, since not every Preview export honors it (see
    /// `useTrueScale` doc comment).
    private func realisticScale(for entity: Entity, species: FishSpecies) -> Float {
        let extents = entity.visualBounds(relativeTo: nil).extents
        let nativeLength = max(extents.x, max(extents.y, extents.z))
        guard nativeLength > 0 else { return 1.0 }

        let realisticLengthMeters = Float(
            (species.lengthRange.min + species.lengthRange.max) / 2
        ) / 100

        let targetLengthMeters = useTrueScale
            ? realisticLengthMeters
            : min(realisticLengthMeters, Self.compactDisplayLengthMeters)

        return targetLengthMeters / nativeLength
    }

    private func isDescendant(_ entity: Entity, of root: Entity) -> Bool {
        var current: Entity? = entity
        while let candidate = current {
            if candidate === root { return true }
            current = candidate.parent
        }
        return false
    }
}
