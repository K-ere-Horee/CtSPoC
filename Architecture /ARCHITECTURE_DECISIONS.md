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

# ADR-020 --- Rod as Controller, World as Game

## Decision

Catch the Scott is a two-device experience with a strict product boundary:
Rod is a physical input device and World is the complete game. World owns
menus, tutorials, calibration instructions, HUD, hook/fish simulation,
results, and progression. Rod owns motion, calibration capture, cast/reel
intent, buttons, connection status, and haptic output.

No gameplay information may be rendered on Rod in V1. World is the sole owner
of gameplay state and player-facing feedback. Rod receives only the input
commands and typed feedback events required to operate the physical
controller.

## Rationale

Keeping the iPhone visually quiet preserves the intended illusion that the
player is holding a fishing rod rather than using a second game screen. It
also prevents gameplay rules, fish state, and presentation logic from being
duplicated across devices.

Status: Accepted

------------------------------------------------------------------------

# ADR-017 --- Cast Resolver Boundary

## Decision

Cast motion is captured once as an immutable `CastSnapshot` containing the
corrected orientation, angular velocity vector, and timestamp. `CastResolver`
converts that snapshot into a `CastSolution` containing normalized power,
horizontal direction, and launch angle.

The motion interpreter detects the release but does not perform gameplay
balancing. World/gameplay consumes the solution and never reads CoreMotion.

## Rationale

Separating motion interpretation from gameplay translation allows cast power,
distance, arc, VFX, audio, and haptics to be balanced without changing the
controller sensor pipeline.

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

# ADR-021 --- Debug First

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

# ADR-019 --- Controller Root and Hook Simulation Separation

## Decision

World keeps `RodRoot` at a fixed camera-relative offset and applies only
`RodState.orientation` to its orientation. Cast direction, power, and distance
are consumed exclusively by hook launch and simulation. Reeling updates the
hook position and never repositions the rod root.

## Rationale

The controller is the player's hand representation, while the hook is the
gameplay projectile. Coupling the rod root to cast distance caused the rod to
move forward during casting and snap back after reeling. Separate entity
ownership keeps the controller attached to the player and makes future fishing
line rendering independent of controller movement.

Status: Accepted

------------------------------------------------------------------------

# ADR-018 --- Gesture Charging and Transform Separation

## Decision

The Rod/Shared motion layer owns gesture phases (`Idle`, `Backswing`,
`Charging`, `Forward Swing`, `Release`, and `Follow Through`) and publishes
live normalized `castPower` in `RodState`. A release is resolved once into a
persistent `CastSolution`; World consumes that solution for hook physics and
HUD presentation.

Rod spatial state and cast gameplay state are separate contracts. Nearby
Interaction distance/direction control the rod root. Cast direction, power,
and distance control only the hook trajectory and cast HUD. World must not
reconstruct cast values from raw motion or use cast distance to move the rod.

## Rationale

Mixing cast output into the rod transform made the controller visibly translate
when a cast was released. Keeping the rod root spatial and the hook dynamic
preserves stable controller rendering while allowing the cast to travel.

Status: Accepted

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
