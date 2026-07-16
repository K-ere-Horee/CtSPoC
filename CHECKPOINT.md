# CtSPoC Implementation Checkpoint

Date: 2026-07-16
Project: Catch the Scott Spatial Controller PoC

## Scope Completed

The first usable PoC pipeline has been implemented according to the repository
architecture documents. Gameplay and fishing mechanics remain intentionally
out of scope.

## Shared Package

Added the platform-independent controller contracts:

- `SpatialState` for Nearby Interaction distance and direction values.
- `RodState` as the single source of truth for timestamp, spatial data, pitch,
  roll, and yaw.
- `ConnectionState` for transport lifecycle state.
- `SpatialStatus` for spatial sensing lifecycle state.
- `TransportProtocol` with async connect, disconnect, and send operations.
- `NetworkMessage.discoveryToken(Data)` for discovery exchange.
- `NetworkMessage.state(RodState)` for controller state streaming.

Shared continues to import Foundation only and contains no app-specific Apple
frameworks.

## Project Integration

The local `Shared` Swift package was added as a package dependency to both
`Rod` and `World` Xcode projects.

Both projects now import the same Shared models and transport contract. There
is no direct World-to-Rod or Rod-to-World dependency.

## Rod Implementation

### Motion

Added `MotionManager` using CoreMotion device motion updates at 30 Hz. It
reports:

- Pitch
- Roll
- Yaw

### Nearby Interaction

Implemented the Rod Nearby Interaction lifecycle:

- Creates an `NISession`.
- Archives and publishes the local discovery token.
- Accepts a remote discovery token.
- Runs `NINearbyPeerConfiguration`.
- Converts nearby distance and direction into `SpatialState`.
- Reports searching, ready, updating, and failed states.

### Transport

Implemented `TransportClient` using MultipeerConnectivity:

- Browses for the World service.
- Invites discovered World peers.
- Tracks connecting, ready, disconnected, and failed states.
- Encodes and decodes `NetworkMessage` with JSON.
- Sends discovery tokens and streaming `RodState` values.

### ViewModel and UI

Added `RodViewModel` as the MainActor orchestration layer. It combines motion
and spatial samples into `RodState`, then streams the state after transport is
ready.

The Rod debug UI displays transport state, Nearby Interaction state, motion
availability, distance, direction, pitch, roll, yaw, timestamp, and errors.

## World Implementation

### Platform Constraint

The current macOS SDK marks `NISession`, `NIDiscoveryToken`,
`NINearbyPeerConfiguration`, and related Nearby Interaction APIs as unavailable
on macOS.

Therefore, World does not create an NI session. Rod owns Nearby Interaction and
sends the resulting spatial values inside `RodState`. World consumes those
values through transport. This is recorded as ADR-014 in
`ARCHITECTURE_DECISIONS.md` and noted in `Spatial_Controller_Architecture.md`.

### World Architecture Refactor

The World refactor is now complete:

- Deleted `World/World/Spatial/NearbyInteractionManager.swift`.
- Removed all World Nearby Interaction dependencies and usage descriptions.
- Removed `spatialManager` and spatial reconstruction from `WorldViewModel`.
- World now assigns received `RodState` directly and updates RealityKit from
  that state.
- Moved Rod sensor files into `Rod/Rod/Sensors/`.
- Rod is the only target that imports `NearbyInteraction`.

### Transport

Implemented `TransportHost` using MultipeerConnectivity:

- Advertises the World service.
- Accepts Rod invitations.
- Tracks peer connection state.
- Decodes incoming `NetworkMessage` values.
- Sends messages when a Rod peer is connected.

### ViewModel and RealityKit

Added `WorldViewModel` as the MainActor state and scene coordinator. It accepts
incoming `RodState` values and updates the spatial relay state.

The World RealityKit scene contains a cube whose position follows the received
direction and distance, and whose orientation follows pitch, roll, and yaw.

The World debug UI displays connection state, spatial state, controller values,
and transport errors.

## Configuration Changes

Added generated Info.plist usage descriptions for:

- Rod motion sensors.
- Rod Nearby Interaction.

World no longer declares Nearby Interaction usage because it has no Nearby
Interaction dependency.

Removed the default SwiftUI `#Preview` blocks because the preview macro cannot
run in the current command-line sandbox environment and is not required by the
runtime applications.

## Verification

Passed:

- Shared source compilation.
- Rod source typecheck against the iOS SDK.
- World source typecheck against the macOS SDK.
- `git diff --check`.
- Static architecture check confirms Shared does not import UI, RealityKit,
  CoreMotion, NearbyInteraction, or other platform frameworks.

Not completed in this environment:

- Full Xcode build through the local Swift package graph. Xcode/SwiftPM stops
  during manifest/cache sandbox execution before compiling the package graph.
- Runtime test between a physical iPhone and a physical Mac.
- Validation of Nearby Interaction hardware behavior and permissions.

## Next Steps

1. Open the Xcode workspace on the development Mac and allow the local Shared
   package to resolve.
2. Build and run World on macOS.
3. Build and run Rod on a physical iPhone with Nearby Interaction capability.
4. Confirm MultipeerConnectivity discovery and connection.
5. Confirm Rod motion values update at runtime.
6. Confirm World receives `RodState` and the RealityKit cube moves and rotates.
7. Add haptics only after the spatial controller pipeline is stable.

Gameplay remains deferred until the spatial controller milestone is proven.

## Latest Refactor Verification

Refactor brief: `World_Architecture_Refactor_Remove_Nearby_Interaction.md`

- World has no `NearbyInteractionManager` file.
- World has no `import NearbyInteraction`.
- World has no `spatialManager` dependency.
- World handles `.state(RodState)` directly in `WorldViewModel`.
- Rod sensor implementations live under `Rod/Rod/Sensors/`.
- Only Rod imports `NearbyInteraction`.
- Rod iOS typecheck passed.
- World macOS typecheck passed.
- `git diff --check` passed.
