# AGENTS.md

# Catch the Scott (CtS) Spatial Controller PoC

## Purpose

This document defines the implementation rules for AI coding agents
working on this repository.

## Asset source repo

The 3D assets `World` loads (`World/World/Assets/Environment/*.usdz`, plus fish) are authored in a
**separate sibling repo**, `~/repos/new-blender-project` (Blender source + docs — start at its root
`CLAUDE.md`). That repo's own `.usdz` exports are the source of truth; the files under
`World/World/Assets/Environment/` are copies and must be kept byte-identical (`shasum` both sides
after any change). If a shipped asset looks visually wrong (bad lighting, missing texture,
malformed geometry) and nothing in this repo's own rendering/material code explains it, check
whether the `.usdz` itself is at fault (`unzip` it, `usdcat` the `.usdc`) before assuming an
app-side bug — see CHECKPOINT.md's "Sky Dome Flat/Gray Bug" entry for a worked example where this
was exactly the case.

Always prioritize correctness, architecture consistency, and small
incremental changes over feature velocity.

------------------------------------------------------------------------

# Project Goal

Build a reusable spatial controller framework.

Current milestone:

-   World (macOS) renders a RealityKit scene.
-   Rod (iPhone) acts as a physical controller.
-   Nearby Interaction provides relative spatial awareness.
-   CoreMotion provides device orientation.
-   CoreHaptics will be added in later milestones.

Do **not** implement fishing gameplay until explicitly requested.

------------------------------------------------------------------------

# Architecture

Workspace

    CtSPoC.xcworkspace
    ├── World
    ├── Rod
    └── Shared

Dependencies

    World ─────► Shared
    Rod ───────► Shared

    World ✗ Rod
    Rod ✗ World

Never introduce direct dependencies between World and Rod.

------------------------------------------------------------------------

# Folder Responsibilities

## Shared

Platform-independent code only.

Allowed:

-   Foundation
-   Swift standard library

Contains:

-   Models
-   Protocols
-   Utilities

Never import:

-   SwiftUI
-   RealityKit
-   ARKit
-   NearbyInteraction
-   CoreMotion
-   CoreHaptics
-   AppKit
-   UIKit

------------------------------------------------------------------------

## World

Responsible for:

-   RealityKit
-   World state
-   Spatial session
-   Debug UI

Never access CoreMotion directly.

------------------------------------------------------------------------

## Rod

Responsible for:

-   CoreMotion
-   Nearby Interaction
-   Haptics
-   Controller state

Never contain RealityKit rendering logic.

------------------------------------------------------------------------

# Design Principles

-   MVVM architecture.
-   Composition over inheritance.
-   Single Responsibility Principle.
-   Protocol-oriented design.
-   async/await preferred.
-   Avoid global state.
-   Avoid singletons unless technically required.

------------------------------------------------------------------------

# Source of Truth

RodState is the only source of truth representing controller state.

Rendering and gameplay consume RodState.

No duplicate controller state should exist elsewhere.

------------------------------------------------------------------------

# Class Naming

Managers

-   MotionManager
-   NearbyInteractionManager
-   TransportHost
-   TransportClient

ViewModels

-   WorldViewModel
-   RodViewModel

Models

-   RodState
-   MotionPacket
-   SpatialState

Protocols

Suffix with:

Protocol

Example:

TransportProtocol

------------------------------------------------------------------------

# Threading

UI:

@MainActor

ViewModels:

@MainActor

Managers:

Actor isolation only where necessary.

Never block the main thread.

------------------------------------------------------------------------

# Coding Style

Prefer:

guard

early return

small functions

immutable structs

Avoid:

deep nesting

force unwrap

large view models

massive classes

------------------------------------------------------------------------

# File Size

Recommended limits

ViewModel

\< 300 lines

Manager

\< 400 lines

View

\< 250 lines

If larger:

Refactor.

------------------------------------------------------------------------

# Framework Usage

Allowed

-   SwiftUI
-   RealityKit
-   NearbyInteraction
-   CoreMotion
-   CoreHaptics
-   Foundation

Avoid deprecated APIs.

Use Apple's latest SDK APIs whenever possible.

------------------------------------------------------------------------

# Development Workflow

Complete one sprint at a time.

Every sprint must:

-   Build successfully.
-   Run successfully.
-   Be independently testable.

Do not skip milestones.

------------------------------------------------------------------------

# Current Roadmap

The original Sprint 0-8 roadmap (project cleanup through fishing gameplay)
shipped long ago; see `Archive/COMPLETED_SPRINT_ROADMAP.md` for the historical
plan. The project is now in ongoing Gameplay V1 refinement — read
`CHECKPOINT.md` (chronological history) and `ARCHITECTURE_DECISIONS.md` (ADR
log) for current state, and `GAMEPLAY_ARCHITECTURE_V1.md` for the product
contract.

------------------------------------------------------------------------

# Pull Request Rules

Every PR must:

-   Compile successfully.
-   Contain a clear description.
-   Include testing notes.
-   Avoid unrelated refactoring.

Keep PRs focused.

------------------------------------------------------------------------

# Definition of Done

A task is complete only when:

-   Builds without errors.
-   No warnings introduced.
-   Architecture remains consistent.
-   Code follows project conventions.
-   Ready for the next sprint.

------------------------------------------------------------------------

# Agent Behavior

The agent must:

-   Respect the existing architecture.
-   Prefer extending existing components over creating new ones.
-   Reuse Shared models whenever possible.
-   Ask for clarification rather than guessing architectural decisions.
-   Keep commits small and incremental.
-   Never introduce gameplay logic before the roadmap allows it.

------------------------------------------------------------------------

# Calibration and Orientation Contract

Calibration is owned by the Rod motion layer and Shared motion models. World
must remain unaware of calibration state and must never apply a calibration
offset.

Required pipeline:

    CoreMotion -> MotionManager -> calibration reference
        -> corrected RodOrientation -> RodState -> Transport -> World

Rules:

-   `MotionPose` contains only raw pitch, roll, and yaw values.
-   `RodOrientation` is the renderer-facing normalized quaternion contract.
-   Calibration captures and persists the Idle reference quaternion.
-   Every runtime frame applies `inverse(reference) * current` in Rod/Shared.
-   `RodState.orientation` is the single renderer-facing orientation source.
-   Euler fields may remain for gameplay-relative motion and diagnostics, but
    World rotation must use `orientation`.
-   Calibration preview and runtime must consume the same corrected pipeline.
-   World must not import or call calibration APIs, store calibration state, or
    reconstruct calibrated orientation from Euler values.
-   Gameplay may classify relative motion after correction, but must not alter
    renderer orientation.

# Casting State and Transform Contract

Gesture charging is owned by the Rod/Shared motion pipeline. The interpreter
publishes the current `RodMotionPhase` and normalized `castPower` on
`RodState`; a release produces the immutable `CastSnapshot` that becomes the
authoritative `CastSolution` through `CastResolver`.

Rules:

-   World owns the cast HUD and renders live power from `RodState.castPower`.
-   `RodState.castSolution` is the only cross-process cast result; World must
    not re-resolve a cast from sensor input.
-   `RodState.directionX/Y/Z`/`distance` (Nearby Interaction) remain spatial-only
    fields, transmitted for potential future use. As of ADR-041, no current
    gameplay or rendering code reads them — the rod root's actual position
    comes from a fixed camera-relative offset (ADR-019), not live NI ranging.
    Do not reintroduce NI-driven rod positioning without a new ADR.
-   Cast direction, power, and distance must never overwrite rod spatial
    position or orientation.
-   The rod root remains fixed relative to the controller pose while the hook
    entity owns cast trajectory and movement.
-   `WorldViewModel.updateRodPose()` may update only the fixed controller
    offset and `RodState.orientation`; it must not read cast distance or cast
    direction.

# Cast Resolver Contract

`RodMotionInterpreter` detects and snapshots a cast. It must not compute
distance, physics, or gameplay balancing.

`CastResolver` consumes only the immutable `CastSnapshot` from `RodState` and
produces `CastSolution` values containing direction, normalized power, and
launch angle. Gameplay and World physics must not read CoreMotion or raw
angular velocity directly.

Power is normalized through `CastConfig`; raw angular velocity never crosses
the motion-to-gameplay boundary as a gameplay value.

# Gameplay Architecture V1 Contract

The V1 product principle is:

> Rod is an input device. World is the game.

World owns the complete player-facing experience: menu, tutorial,
calibration instructions, fishing HUD, hook and fish simulation, results,
progression, and future inventory/shop/collection systems. Rod remains a
minimal physical controller for motion input, calibration capture, cast/reel
intent, buttons, connection status, and haptic output.

Rules:

-   Rod must not display gameplay HUD, fish information, tutorials,
    progression, or catch results.
-   World is the only owner of gameplay state, gameplay visuals, and gameplay
    feedback.
-   The World gameplay state machine is Connect -> Calibration -> Ready ->
    Cast -> Hook Flying -> Splash -> Searching -> Interested -> Bite ->
    Fight -> Catch/Escape -> Result -> Continue/Menu.
-   Cast Meter and Line Tension Meter are World HUD components. They consume
    shared state and gameplay state; they never read CoreMotion directly.
-   Fish selection is data-driven through biome, water type, equipment, bait,
    difficulty, and probability tables.
-   Fish resistance is expressed through line tension and Rod haptics, not a
    generic health bar or quick-time-event loop.
-   Rod haptics are output feedback only. World decides the gameplay event and
    sends a typed feedback/event contract to Rod.

The full V1 vision and state definitions live in
`GAMEPLAY_ARCHITECTURE_V1.md`. Documentation-only tasks must not modify Swift,
project files, or runtime structure, and must still be recorded in
`CHECKPOINT.md`.

When a task concerns product behavior, use `GAMEPLAY_ARCHITECTURE_V1.md` as
the source of truth. World owns gameplay state, gameplay visuals, tutorials,
fish systems, progression, and player feedback. Rod may expose only controller
actions, connection state, calibration controls, and haptic output.

For documentation-only requests, update the relevant `.md` files and create a
dedicated design document when the subject does not have an existing owner.
Do not modify Swift, Xcode projects, assets, or folder structure as part of a
documentation-only task.
