//
//  FishPreviewARViewContainer.swift
//  Rod
//
//  ADR-127: a deliberate, narrow exception to "Rod never contains RealityKit
//  rendering logic" (AGENTS.md), scoped only to this file and the rest of
//  Rod/Rod/Reality/. Rod is the device already in the player's hand, and
//  World's RealityView runs non-AR/virtual (ADR-030) with no passthrough
//  surface — so the standalone, non-gameplay AR fish preview lives here
//  instead.
//

import ARKit
import RealityKit
import SwiftUI

/// Wraps an `ARView` running world tracking with horizontal plane detection,
/// a coaching overlay, and tap-to-place / tap-to-inspect gestures. Owns no
/// gameplay state itself; all placement/selection state lives in
/// `FishPreviewViewModel`.
struct FishPreviewARViewContainer: UIViewRepresentable {

    @ObservedObject var viewModel: FishPreviewViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)

        // Real `UsdPreviewSurface` materials are fully light-dependent.
        // Rather than boosting ARKit's own ambient/IBL estimate (unpredictable
        // and room-dependent — stacking it on top of explicit lights is what
        // overexposed pale-colored species after the first lighting pass),
        // visibility is guaranteed by the fixed, predictable key + fill light
        // added per-anchor in `FishPreviewViewModel`, so real-world lighting
        // stays a minor contribution instead of compounding unpredictably.

        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.frame = arView.bounds
        arView.addSubview(coachingOverlay)

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)
        context.coordinator.arView = arView

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Placement/selection state is driven imperatively through
        // `viewModel` (from the coordinator and from the picker/reset UI),
        // not by re-diffing the view here.
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    @MainActor
    final class Coordinator: NSObject {
        let viewModel: FishPreviewViewModel
        weak var arView: ARView?

        init(viewModel: FishPreviewViewModel) {
            self.viewModel = viewModel
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }
            let point = recognizer.location(in: arView)

            guard viewModel.isPlaced else {
                guard let result = arView.raycast(
                    from: point,
                    allowing: .estimatedPlane,
                    alignment: .horizontal
                ).first else { return }
                viewModel.placeFish(at: result.worldTransform, in: arView)
                return
            }

            guard let tappedEntity = arView.entity(at: point) else { return }
            viewModel.handleTap(on: tappedEntity)
        }
    }
}
