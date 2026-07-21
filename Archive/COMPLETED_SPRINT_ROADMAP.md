# Completed Sprint 0-8 Roadmap (Archived)

Archived 2026-07-20. This is the original sprint-by-sprint roadmap that used
to live in `AGENTS.md` ("Current Roadmap") and `SOFTWARE_ARCHITECTURE_DOCUMENT.md`
("Implementation Plan") — the two copies were near-identical. All eight
sprints shipped long ago; the project is now well past Sprint 8 into ongoing
Gameplay V1 refinement (fish tiers, fight tuning, transport migration, audio,
etc. — see `CHECKPOINT.md` and `ARCHITECTURE_DECISIONS.md` for what actually
happened and in what order). Kept here for historical reference only; it is
not a current plan and should not be used to judge what's "next."

------------------------------------------------------------------------

## Sprint 0 - Project Foundation

- Verify Workspace builds.
- Verify Shared imports into both apps.
- Remove template code.

Deliverable: Clean project.

## Sprint 1 - Shared Package

Implement:

- RodState
- MotionPacket
- SpatialState
- TransportProtocol
- Constants

Deliverable: Shared compiles independently.

## Sprint 2 - Nearby Interaction

Implement:

- NearbyInteractionManager (World)
- NearbyInteractionManager (Rod)
- Session lifecycle
- Discovery exchange abstraction

Deliverable: Session established.

## Sprint 3 - Motion

Implement:

- MotionManager
- Pitch
- Roll
- Yaw

Display locally.

Deliverable: Stable motion values.

## Sprint 4 - Controller State

Merge:

- Motion
- Spatial

into RodState.

Deliverable: Single source of truth.

## Sprint 5 - Synchronization

Stream RodState to World.

Display:

- Distance
- Direction
- Pitch
- Roll
- Yaw

Deliverable: Both devices show synchronized values.

## Sprint 6 - RealityKit

Create:

- RealityScene
- Debug cube

Cube reacts to RodState.

Deliverable: Visible motion synchronization.

## Sprint 7 - Gesture Engine / Gesture Detection

Detect:

- Idle
- Cast
- Reel

Deliverable: Discrete controller events.

## Sprint 8 - Fishing Prototype

Implement:

- Hook
- Fish
- Catch
- Haptics
