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

## Commit-by-Commit Architecture Update

This section records the commit history after the original foundation was
implemented. Previous checkpoint sections remain unchanged above.

### `ea63d27` - Spatial Controller Foundation

Commit topic: establish the first end-to-end spatial controller PoC.

Architecture changes:

- Established the Shared package as the contract layer between the two apps.
- Made `RodState` the single source of truth for controller state.
- Assigned CoreMotion and Nearby Interaction sensing to Rod.
- Added transport flow between Rod and World.
- Added RealityKit debug visualization and debug overlays.
- Kept gameplay deferred until sensing and streaming are validated.

Key files and responsibilities:

- `Shared/Sources/Shared/Models/ConnectionState.swift`: transport lifecycle.
- `Shared/Sources/Shared/Models/SpatialStatus.swift`: spatial lifecycle.
- `Shared/Sources/Shared/Models/NetworkMessage.swift`: state/discovery messages.
- `Shared/Sources/Shared/Protocols/Transport.swift`: shared transport contract.
- `Rod/Rod/Motion/MotionManager.swift`: CoreMotion orientation sampling.
- `Rod/Rod/Spatial/NearbyInteractionManager.swift`: Rod NI session and spatial
  samples.
- `Rod/Rod/Transport/TransportClient.swift`: Rod peer discovery and messages.
- `Rod/Rod/ViewModel/RodViewModel.swift`: combines motion and spatial samples
  into `RodState` and streams it.
- `World/World/Transport/TransportHost.swift`: World peer advertising and
  message receiving.
- `World/World/ViewModels/WorldViewModel.swift`: consumes state and drives the
  RealityKit entity.
- `World/World/ContentView.swift` and `Rod/Rod/ContentView.swift`: debug UI.

Data flow introduced:

```text
CoreMotion + Nearby Interaction
            |
            v
         RodState
            |
            v
   MultipeerConnectivity transport
            |
            v
       WorldViewModel
            |
            v
        RealityKit
```

### `0c6454b` - Move All Sensing to Rod

Commit topic: remove unsupported World interaction code and make World a state
consumer/capturer only.

Architecture changes:

- Deleted `World/World/Spatial/NearbyInteractionManager.swift`.
- Removed `spatialManager` and `SpatialStatus` handling from
  `WorldViewModel`.
- Changed World message flow from `Transport -> spatial manager -> scene` to
  `Transport -> RodState -> WorldViewModel -> scene`.
- Moved Rod sensor files from separate `Motion` and `Spatial` folders into
  `Rod/Rod/Sensors/`.
- Updated the architecture document to state that Rod owns NI and World never
  imports or manages NI.
- Added iOS and macOS v26 platform declarations to `Shared/Package.swift`.

Files changed:

- `Rod/Rod/Sensors/MotionManager.swift`.
- `Rod/Rod/Sensors/NearbyInteractionManager.swift`.
- `World/World/ViewModels/WorldViewModel.swift`.
- `World/World/ContentView.swift`.
- `World/World.xcodeproj/project.pbxproj`.
- `Spatial_Controller_Architecture.md`.
- `Shared/Package.swift`.

Resulting flow:

```text
Rod sensors -> RodState -> TransportHost -> WorldViewModel -> RealityKit
```

There is no World-side spatial reconstruction. This commit is the concrete
implementation of the macOS Nearby Interaction platform constraint documented
in ADR-014.

### `11127d2` - Runtime Transport Diagnostics and Rod Asset

Commit topic: add runtime diagnostics, explicit app configuration, peer model
scaffolding, and a Rod 3D asset for World.

Architecture changes:

- Added explicit `Info.plist` files for Rod and World.
- Added `World/World/Assets/Rod.usdz` as the preferred RealityKit visual asset.
- Updated World scene loading to asynchronously load the `Rod` USDZ asset.
- Kept a red cube fallback when the USDZ asset cannot be loaded.
- Added transport initialization, browsing, advertising, invitation, and peer
  state logs for runtime diagnosis.
- Added `PeerInfo` in Shared as a future peer identity model.

Files changed:

- `Rod/Rod/Info.plist`.
- `World/World/Info.plist`.
- `World/World/Assets/Rod.usdz`.
- `Shared/Sources/Shared/Models/PeerInfo.swift`.
- `Rod/Rod/Transport/TransportClient.swift`.
- `World/World/Transport/TransportHost.swift`.
- `World/World/ViewModels/WorldViewModel.swift`.
- `World/World/ContentView.swift`.
- Both Xcode project files for asset and plist integration.

Runtime flow after this commit:

```text
World start
  -> TransportHost starts advertising
Rod start
  -> TransportClient starts browsing
Peer discovered
  -> Rod invites World
Invitation received
  -> World accepts invitation
Session connected
  -> Rod streams RodState
World receives RodState
  -> WorldViewModel updates Rod.usdz or fallback cube
```

The diagnostic logs include client/host initialization, browsing/advertising
start, peer state transitions, invitation receipt, and detailed browser or
advertiser failure information.

### Earlier Repository Baseline

For context, the history before the foundation was:

- `998b84d`: initial Xcode workspace and app targets.
- `9d8f252`: renamed placeholder networking/view-model files and added initial
  Shared motion/network placeholders.
- `a3e3533`: added the architecture documents, Shared models/protocols, and
  initial manager/transport skeleton names.

### Current Branch State

- Branch: `dev`.
- `HEAD`: `11127d2` (`origin/dev` points to the same commit).
- `main` remains at `9d8f252`.
- Existing checkpoint content is preserved.
- The current worktree also contains a user-modified Xcode UI state file; it is
  not part of this commit audit.

## Gameplay Vertical Slice - Casting and Reeling

Roadmap source: `CtSPoC_Gameplay_Vertical_Slice_Roadmap.md`

The first playable gameplay loop is now implemented without fish, score,
fishing line, VFX, or polished assets:

```text
Idle -> Casting -> Hook Flying -> Hook In Water -> Reeling -> Idle
```

### Shared Gameplay Contract

Added `RodAction` in `Shared/Sources/Shared/Models/RodAction.swift`:

- `idle`
- `casting`
- `reeling`

`RodState` now includes `action` and `reelSpeed`. Rod still owns sensing and
intention; World remains the owner of gameplay simulation.

### Rod Gesture Detection

`MotionManager` now exposes:

- `userAcceleration.z` for cast detection.
- Magnitude of the device rotation rate for reeling intensity.

`RodActionDetector` maps the sensor samples to gameplay intent:

- A positive Z acceleration greater than `1.25` triggers `.casting`.
- Casting stays active for `0.25` seconds with an `0.8` second cooldown.
- Rotation magnitude above `1.4` triggers `.reeling`.
- Rotation magnitude is normalized to `RodState.reelSpeed` in the `0...1`
  range.

`RodViewModel` publishes the action and reel speed in each streamed `RodState`.
The Rod debug view displays action, reel speed, cast acceleration, and rotation
rate.

### World Hook Simulation

`WorldViewModel` now creates one root scene containing:

- The Rod USDZ entity, with the existing red cube fallback.
- A small yellow sphere representing the hook.
- A simple blue water plane at a fixed water height.

The simulation runs at a fixed 60 Hz cadence on the main actor:

- Receiving `.casting` launches the hook from the rod forward direction.
- The hook uses manual velocity integration and gravity while flying.
- Reaching the water plane stops the hook in the `hookInWater` phase.
- While Rod sends `.reeling`, the hook moves toward the rod using the streamed
  reel speed.
- Once the hook is near the rod, it hides and returns to `idle`.

World debug UI now shows the Rod action, hook phase, and reel speed alongside
the existing pose values.

### Scope Intentionally Deferred

- Fishing line rendering.
- Fish AI and attachment.
- Catch, score, and progression.
- Haptics, VFX, and gameplay polish.

### Vertical Slice Verification

- Shared module compiles for iOS and macOS SDK targets.
- Rod source typechecks with the iOS SDK.
- World source typechecks with the macOS SDK.
- Shared remains platform independent.
- `git diff --check` passes.

## Rod Orientation Refactor

Roadmap source: `CtSPoC_Rod_Orientation_Refactor.md`

World now separates tracking transforms from the visual asset transform:

```text
Scene Root
|- Water
|- RodRoot       <- position and orientation from RodState
|  `- Rod.usdz   <- static model pitch/yaw/roll offset
`- Hook
```

`WorldViewModel` keeps separate references to `controllerEntity` (`RodRoot`)
and `rodModel` (`Rod.usdz`). `updateRodPose()` applies the live controller
tracking only to `RodRoot`, while `updateModelOrientation()` applies the asset
correction only to `Rod.usdz`.

The model starts with a 180 degree pitch correction to address the upside-down
asset orientation. DEBUG builds expose live Pitch, Yaw, and Roll sliders under
the RealityView so the final asset offset can be tuned without rebuilding.

## Gameplay Haptics

Roadmap source: `CtSPoC_Haptics_Design_Roadmap.md`

Haptics are now event-driven and remain entirely inside Rod:

```text
Rod motion / World gameplay outcome
              |
              v
         FishingEvent
              |
              v
        FishingHaptics
              |
              v
         HapticManager
              |
              v
         Core Haptics
```

Added shared `FishingEvent` values for cast, hook splash, reel tick, fish bite,
fish escape, catch, and line break. The event type is transportable through
`NetworkMessage.fishingEvent` without adding Core Haptics to Shared or World.

Rod haptic behavior currently implemented:

- A cast pulse when the action transitions to `.casting`.
- Repeating low-intensity reel ticks whose interval scales with reel speed.
- A light splash pulse when World reports the hook reached water.

`HapticManager` also exposes patterns for future fish bite, catch, and line
break events. World emits `hookSplash` when the simulated hook reaches the
water plane; Rod receives the event through transport and plays the feedback.

### Orientation and Haptics Verification

- World source typechecks after the RodRoot hierarchy refactor.
- Rod source typechecks with Core Haptics integration.
- Shared source typechecks for iOS and macOS SDK targets.
- Only Rod imports `CoreHaptics`.
- `git diff --check` passes.

## Rod Motion Constraints and Casting

Design source: `CtSPoC_Rod_Motion_Constraints_and_Casting_Design.md`

The Rod motion pipeline now interprets device motion before it becomes
`RodState` or gameplay intent:

```text
CoreMotion -> RodMotionInterpreter -> constrained RodState -> World
```

### Home Orientation and Normalization

- `RodMotionInterpreter` records the first motion sample as the home
  orientation and exposes recalibration from the Rod debug UI.
- Pitch, roll, and yaw are calculated relative to that reference rather than
  forwarded in world coordinates.
- Home roll is represented by the neutral in-range value `2.0` radians, so a
  newly calibrated controller begins in a valid rod pose.

### Constraints, Filtering, and Pose Gating

- Virtual rod pose is clamped to pitch `-0.3...1.0`, roll `1.0...3.0`, and
  yaw `-2.5...2.5` radians before it is sent to World.
- The interpreter first validates the un-clamped pose. An out-of-range device
  pose yields `.invalid`, disables casting and reeling, and still provides a
  clamped visual pose for World.
- Constrained orientation is low-pass interpolated with a smoothing factor of
  `0.18`, avoiding raw 1:1 device rotation in the visual rod.
- The local motion lifecycle is now `invalid`, `ready`, `casting`, `waiting`,
  or `reeling`; Rod displays the phase and pose validity for runtime tuning.

### Casting Changes

- Removed `RodActionDetector` and its acceleration-threshold casting logic.
- Casting now requires a valid pose, a positive relative pitch delta of at
  least `0.12` radians, and an expired cooldown.
- A cast remains active for `0.25` seconds, then the interpreter waits until
  the required `0.5` second cooldown has elapsed before allowing another cast.
- Reeling remains rotation-rate driven, but is also disabled outside the valid
  pose range.

### Files Changed

- `Shared/Sources/Shared/Gameplay/RodMotionInterpreter.swift`: platform-
  independent normalization, constraints, smoothing, and gesture inference.
- `Rod/Rod/Sensors/MotionManager.swift`: includes the CoreMotion timestamp in
  each sample.
- `Rod/Rod/ViewModel/RodViewModel.swift`: owns the interpreter and publishes
  its constrained pose and intent through `RodState`.
- `Rod/Rod/ContentView.swift`: displays pose state and adds home-orientation
  calibration.
- Deleted `Rod/Rod/Sensors/RodActionDetector.swift` because acceleration is no
  longer a gameplay action source.

### Verification

- Shared source typechecks against the macOS SDK.
- Rod source typechecks against the iOS SDK with the complete Shared module.
- `git diff --check` passes.
- Full SwiftPM build remains unavailable in this environment because its
  manifest invocation is blocked by the local Xcode sandbox.
