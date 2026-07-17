# ARCHITECTURE_DECISIONS.md

# CtS PoC - Architecture Decision Record (ADR)

Version: 1.0

This document records architectural decisions that are considered stable
for the Catch the Scott Spatial Controller PoC. Future changes should
preserve these decisions unless there is a compelling technical reason
to revise them.

------------------------------------------------------------------------

# ADR-001 --- World/Rod Separation

## Decision

Split the application into two independent apps.

-   World (macOS)
-   Rod (iPhone)

## Rationale

The renderer and the controller have different responsibilities.

Benefits:

-   Easier testing
-   Independent deployment
-   Cleaner architecture
-   Reusable controller

Status: Accepted

------------------------------------------------------------------------

# ADR-002 --- Shared Swift Package

## Decision

All shared models and protocols live inside the Shared Swift Package.

## Rationale

Avoid code duplication.

World and Rod communicate using identical models.

Status: Accepted

------------------------------------------------------------------------

# ADR-003 --- RodState is the Single Source of Truth

## Decision

All controller information is represented by one model.

``` swift
RodState
```

Gameplay and rendering consume RodState only.

No duplicate motion state may exist.

Status: Accepted

------------------------------------------------------------------------

# ADR-004 --- Separation of Motion and Spatial Data

## Decision

CoreMotion and Nearby Interaction remain independent.

Motion:

-   Pitch
-   Roll
-   Yaw

Spatial:

-   Distance
-   Direction

RodState combines both domains.

Status: Accepted

------------------------------------------------------------------------

# ADR-005 --- RealityKit Exists Only in World

## Decision

RealityKit rendering belongs exclusively to World.

Rod never renders the simulation.

## Rationale

Rod is a physical controller.

Status: Accepted

------------------------------------------------------------------------

# ADR-006 --- Rod Never Depends on Reality

Rod must never import:

-   RealityKit
-   ARKit

Its responsibility is sensing and input.

Status: Accepted

------------------------------------------------------------------------

# ADR-007 --- Shared Must Be Platform Independent

Shared may import:

-   Foundation

Shared must not import:

-   SwiftUI
-   RealityKit
-   CoreMotion
-   NearbyInteraction
-   CoreHaptics
-   UIKit
-   AppKit

Status: Accepted

------------------------------------------------------------------------

# ADR-008 --- MVVM

Use MVVM throughout the project.

Views remain passive.

Business logic belongs in ViewModels and Managers.

Status: Accepted

------------------------------------------------------------------------

# ADR-009 --- Composition Over Inheritance

Prefer composition and protocols.

Avoid deep inheritance hierarchies.

Status: Accepted

------------------------------------------------------------------------

# ADR-010 --- Incremental Delivery

Implementation proceeds sprint-by-sprint.

Each sprint must:

-   Build
-   Run
-   Be testable

No sprint may depend on unfinished work.

Status: Accepted

------------------------------------------------------------------------

# ADR-011 --- Gameplay Deferred

Fishing mechanics are intentionally postponed.

Priority:

1.  Spatial session
2.  Motion
3.  Synchronization
4.  Reality visualization
5.  Gesture recognition
6.  Gameplay

Status: Accepted

------------------------------------------------------------------------

# ADR-012 --- Apple-First APIs

Use the latest stable Apple SDKs.

Prefer:

-   Nearby Interaction
-   RealityKit
-   CoreMotion
-   CoreHaptics
-   Swift Concurrency

Avoid deprecated APIs in new implementations.

Status: Accepted

------------------------------------------------------------------------

# ADR-013 --- Loose Coupling

World and Rod communicate only through shared contracts.

------------------------------------------------------------------------

# ADR-014 --- Nearby Interaction Ownership

## Decision

Rod owns the Nearby Interaction session. World receives the resulting spatial
state through `RodState` over the shared transport contract.

## Rationale

The current macOS SDK marks `NISession` and its peer configuration APIs as
unavailable on macOS. Keeping the NI implementation on Rod preserves the
physical-controller model while allowing World to run as a native macOS app.

No project may import the other project.

Status: Accepted

------------------------------------------------------------------------

# ADR-014 --- Debug First

Every subsystem should expose observable debug information before
gameplay is implemented.

Examples:

-   Session state
-   Distance
-   Direction
-   Pitch
-   Roll
-   Yaw
-   Update frequency

Status: Accepted

------------------------------------------------------------------------

# ADR-015 --- Reusable Spatial Controller

The long-term objective is not a fishing game.

The objective is a reusable spatial controller framework capable of
supporting multiple interaction paradigms such as:

-   Fishing rod
-   Tennis racket
-   Baseball bat
-   Golf club
-   Sword
-   Other spatial interaction experiences

Fishing is the first consumer of the framework.

Status: Accepted

------------------------------------------------------------------------

# Change Policy

Any modification to these decisions should:

1.  Explain why the existing decision is insufficient.
2.  Describe the proposed alternative.
3.  Document trade-offs.
4.  Be approved before implementation.

Architectural consistency takes priority over short-term implementation
convenience.

------------------------------------------------------------------------

# ADR-016 --- Calibration-Owned Orientation

## Decision

Calibration belongs to the Rod/Shared motion pipeline. The calibration layer
captures and persists an Idle reference quaternion, applies its inverse to each
current device orientation, and publishes the corrected orientation in
`RodState.orientation`.

World consumes that orientation as-is. World does not know whether a
calibration reference exists and does not apply offsets or reconstruct the
calibrated orientation from Euler angles.

Gameplay-relative pose may be derived separately from corrected motion, but it
must not become the renderer's orientation source.

## Rationale

Using relative Euler values for both gameplay and rendering caused the rod to
appear to snap when calibration ended. A normalized quaternion contract keeps
the visual pipeline stable and makes the ownership boundary explicit.

Status: Accepted
