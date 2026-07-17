# AGENTS.md

# Catch the Scott (CtS) Spatial Controller PoC

## Purpose

This document defines the implementation rules for AI coding agents
working on this repository.

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

Sprint 0

Project cleanup

Sprint 1

Shared models

Sprint 2

Nearby Interaction session

Sprint 3

CoreMotion

Sprint 4

RodState

Sprint 5

Synchronization

Sprint 6

RealityKit visualization

Sprint 7

Gesture detection

Sprint 8

Fishing gameplay

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
