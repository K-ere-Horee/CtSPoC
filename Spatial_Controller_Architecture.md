# CtS PoC - Spatial Controller Architecture

## Overview

This document updates the architecture for the Catch the Scott PoC.

The project is centered around **Nearby Interaction** as the spatial
sensing technology, **RealityKit** as the renderer, and **CoreMotion**
as the motion input provider.

The first milestone is **not** to build the fishing game.

The first milestone is to prove that an iPhone can function as a spatial
controller for a RealityKit application running on macOS.

------------------------------------------------------------------------

## Goals

-   macOS hosts the RealityKit world.
-   iPhone acts as the controller.
-   Nearby Interaction provides relative distance and direction.
-   CoreMotion provides orientation (pitch, roll, yaw).
-   CoreHaptics is reserved for future feedback.

------------------------------------------------------------------------

## Success Criteria

-   Nearby Interaction session established.
-   Discovery information exchanged successfully.
-   Mac receives distance and direction.
-   iPhone streams pitch, roll, and yaw.
-   Both devices display synchronized debug values.

No gameplay is required.

------------------------------------------------------------------------

## High-Level Architecture

                    World (macOS)

               RealityKit Renderer
                       │
               World Simulation
                       │
         NearbyInteractionManager
                       │
                Transport Layer
                       ▲
    ────────────────────────────────
                       ▼
                Transport Layer
                       │
         NearbyInteractionManager
                       │
               CoreMotionManager
                       │
              CoreHapticsManager

                  Rod (iPhone)

------------------------------------------------------------------------

## Responsibilities

### World

-   Render RealityKit scene
-   Manage world state
-   Receive controller state
-   Display debug values
-   Manage Nearby Interaction session

### Rod

-   Read CoreMotion
-   Participate in Nearby Interaction
-   Build controller state
-   Display debug values
-   Trigger haptics (future)

------------------------------------------------------------------------

## Project Structure

### World

    World/
    ├── Reality/
    ├── Spatial/
    │   └── NearbyInteractionManager.swift
    ├── Transport/
    │   └── TransportHost.swift
    ├── ViewModels/
    └── Views/

### Rod

    Rod/
    ├── Motion/
    │   └── MotionManager.swift
    ├── Spatial/
    │   └── NearbyInteractionManager.swift
    ├── Transport/
    │   └── TransportClient.swift
    ├── Haptics/
    └── Views/

### Shared

    Shared/
    ├── Models/
    ├── Protocols/
    └── Utilities/

------------------------------------------------------------------------

## Shared Model

``` swift
public struct RodState: Codable {

    public let timestamp: TimeInterval

    public let distance: Float?

    public let directionX: Float?
    public let directionY: Float?
    public let directionZ: Float?

    public let pitch: Double
    public let roll: Double
    public let yaw: Double
}
```

------------------------------------------------------------------------

## Layer Responsibilities

### Nearby Interaction

-   Session lifecycle
-   Relative distance
-   Relative direction
-   Peer tracking

### CoreMotion

-   Pitch
-   Roll
-   Yaw

### Transport

Responsible only for exchanging discovery information and application
data.

------------------------------------------------------------------------

## Debug Overlay

Display on both devices:

-   Connection State
-   Distance
-   Direction (X/Y/Z)
-   Pitch
-   Roll
-   Yaw
-   Update Rate

------------------------------------------------------------------------

## Development Roadmap

### Milestone 1

-   Project structure
-   Shared package
-   NearbyInteractionManager skeleton
-   Transport abstraction

### Milestone 2

-   Discovery exchange
-   Establish NI session
-   Verify connection

### Milestone 3

-   Distance and direction
-   Live debug values

### Milestone 4

-   CoreMotion integration
-   Build RodState

### Milestone 5

-   RealityKit cube follows RodState

### Milestone 6

-   Gesture detection
    -   Cast
    -   Reel
    -   Idle

### Milestone 7

-   Fishing gameplay

------------------------------------------------------------------------

## Design Principles

-   RealityKit never reads CoreMotion directly.
-   Nearby Interaction is treated as a spatial sensor.
-   Motion and spatial information remain independent until combined
    into RodState.
-   Gameplay depends only on RodState.
-   Components remain loosely coupled.

------------------------------------------------------------------------

## Long-Term Vision

The controller architecture can later power:

-   Fishing rod
-   Baseball bat
-   Tennis racket
-   Golf club
-   Sword
-   Other spatial interaction experiences
