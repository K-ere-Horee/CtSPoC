# CtS Software Architecture Document (SAD)

## Catch the Scott - Spatial Controller PoC

Version: 1.0

# 1. Vision

Build a reusable spatial controller framework where:

-   World (macOS) hosts the RealityKit simulation.
-   Rod (iPhone) behaves as a physical controller.
-   Nearby Interaction provides relative spatial awareness.
-   CoreMotion provides orientation.
-   CoreHaptics provides feedback in later milestones.

Gameplay is intentionally excluded from Phase 1.

------------------------------------------------------------------------

# 2. Architecture

                    Shared (Swift Package)

     Models
     Protocols
     Utilities

            ▲                    ▲

            │                    │

       World (macOS)         Rod (iPhone)

     RealityKit             CoreMotion
     ViewModel              MotionManager
     NearbyInteraction      NearbyInteraction
     Transport              Transport

Dependencies:

-   World -\> Shared
-   Rod -\> Shared
-   World and Rod never depend on each other.

------------------------------------------------------------------------

# 3. Components

## Shared

Purpose: Common models, protocols and utilities.

Contains:

-   RodState
-   MotionPacket
-   SpatialState
-   Transport protocol
-   Codable helpers

Never imports: - RealityKit - CoreMotion - SwiftUI

------------------------------------------------------------------------

## World

Responsibilities

-   RealityKit rendering
-   World simulation
-   NI session
-   Receive RodState
-   Debug overlay

Folders

Reality/ Spatial/ Transport/ ViewModels/ Views/

------------------------------------------------------------------------

## Rod

Responsibilities

-   CoreMotion
-   NI session
-   Produce RodState
-   Debug overlay
-   Future haptics

Folders

Motion/ Spatial/ Transport/ Haptics/ Views/

------------------------------------------------------------------------

# 4. Data Flow

    CoreMotion
          │
          ▼
    MotionManager
          │
          ▼
    RodState
          │
          ▼
    Transport
          │
          ▼
    World
          │
          ▼
    RealityKit

Nearby Interaction updates RodState independently.

------------------------------------------------------------------------

# 5. Threading

-   UI: MainActor
-   RealityKit: MainActor
-   CoreMotion callbacks -\> isolated manager
-   Transport -\> async/await
-   Nearby Interaction delegates -\> ViewModel

------------------------------------------------------------------------

# 6. State Machine

    Idle

    ↓

    Searching

    ↓

    Connecting

    ↓

    Session Ready

    ↓

    Streaming

    ↓

    Disconnected

    ↺

------------------------------------------------------------------------

# 7. Class Responsibilities

Rod

-   MotionManager
-   NearbyInteractionManager
-   TransportClient
-   RodViewModel

World

-   NearbyInteractionManager
-   TransportHost
-   WorldViewModel
-   RealityScene

Shared

-   RodState
-   MotionPacket
-   TransportProtocol

------------------------------------------------------------------------

# 8. Error Handling

Recover from:

-   Session invalidation
-   Peer disconnect
-   Missing spatial updates
-   Motion unavailable

Always attempt reconnection.

------------------------------------------------------------------------

# 9. Coding Rules

-   MVVM only.
-   Single Responsibility Principle.
-   Shared contains platform-independent code only.
-   No singleton unless justified.
-   async/await preferred.
-   Protocol-first design.

------------------------------------------------------------------------

# Implementation Plan

## Sprint 0 - Project Foundation

-   Verify Workspace builds.
-   Verify Shared imports into both apps.
-   Remove template code.

Deliverable: Clean project.

------------------------------------------------------------------------

## Sprint 1 - Shared Package

Implement:

-   RodState
-   MotionPacket
-   SpatialState
-   TransportProtocol
-   Constants

Deliverable: Shared compiles independently.

------------------------------------------------------------------------

## Sprint 2 - Nearby Interaction

Implement:

-   NearbyInteractionManager (World)
-   NearbyInteractionManager (Rod)
-   Session lifecycle
-   Discovery exchange abstraction

Deliverable: Session established.

------------------------------------------------------------------------

## Sprint 3 - Motion

Implement:

-   MotionManager
-   Pitch
-   Roll
-   Yaw

Display locally.

Deliverable: Stable motion values.

------------------------------------------------------------------------

## Sprint 4 - Controller State

Merge:

-   Motion
-   Spatial

into RodState.

Deliverable: Single source of truth.

------------------------------------------------------------------------

## Sprint 5 - Synchronization

Stream RodState to World.

Display:

-   Distance
-   Direction
-   Pitch
-   Roll
-   Yaw

Deliverable: Both devices show synchronized values.

------------------------------------------------------------------------

## Sprint 6 - RealityKit

Create:

-   RealityScene
-   Debug cube

Cube reacts to RodState.

Deliverable: Visible motion synchronization.

------------------------------------------------------------------------

## Sprint 7 - Gesture Engine

Detect:

-   Idle
-   Cast
-   Reel

Deliverable: Discrete controller events.

------------------------------------------------------------------------

## Sprint 8 - Fishing Prototype

Implement:

-   Hook
-   Fish
-   Catch
-   Haptics

------------------------------------------------------------------------

# Agent Instructions

The implementation agent must follow these rules:

1.  Complete exactly one sprint at a time.
2.  Every sprint must compile before moving on.
3.  Never introduce gameplay before Sprint 8.
4.  Never bypass Shared models.
5.  Keep Nearby Interaction, Motion, RealityKit and Transport in
    separate modules.
6.  Prefer composition over inheritance.
7.  Use Apple's latest SDK APIs only.
8.  Write small, testable classes.
9.  Keep ViewModels free from rendering code.
10. Treat RodState as the single source of truth for controller state.

------------------------------------------------------------------------

## Calibration Orientation Pipeline

The motion system has two related outputs with separate responsibilities:

```text
Raw Device Orientation -> Calibration Reference -> Corrected RodOrientation
                                      -> RodState.orientation -> World
                                      -> Relative Motion Pose -> Gameplay
```

Rod captures and persists the Idle reference, applies
`inverse(reference) * current` on every frame, and sends the corrected result
in `RodState.orientation`. World only renders that value and must not calculate
calibration, apply offsets, remember an Idle reference, or use relative pose
for visual rotation.

------------------------------------------------------------------------

## Cast Resolver Pipeline

Cast release follows a separate gameplay translation boundary:

```text
RodMotionInterpreter -> CastSnapshot -> RodState -> CastResolver
                    -> CastSolution -> Gameplay/World Physics
```

`CastSnapshot` is immutable and contains corrected orientation, angular
velocity, and timestamp. `CastResolver` computes horizontal direction,
normalized power, and launch angle. Raw angular velocity is never exposed to
gameplay as a balancing value.

Definition of Done for each sprint:

-   Builds successfully.
-   Runs on target device(s).
-   No warnings.
-   Code reviewed for architecture.
-   Ready for the next sprint.
