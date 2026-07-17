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

## Hook Phase Synchronization

Design source: `CtSPoC_Hook_Phase_Synchronization_Design.md`

World is now the authority for the hook gameplay lifecycle. The lifecycle is
shared as `HookPhase` and synchronized to Rod through `NetworkMessage`:

```text
World hook simulation -> HookPhase -> transport -> RodViewModel casting gate
```

### Architecture and Flow Changes

- Added `Shared/Sources/Shared/Models/HookPhase.swift` with the shared phases
  `idle`, `flying`, `hookInWater`, and `reeling`.
- Extended `NetworkMessage` with `.hookPhase(HookPhase)` so World can publish
  every authoritative lifecycle transition to Rod.
- Removed the World-local `HookPhase` enum so both applications use the same
  Codable shared type.
- Centralized World lifecycle mutations in `setHookPhase(_:)`; launch, water
  impact, reeling, and hook completion now broadcast through this helper.
- Added a `hookPhase` state to `RodViewModel` and handled incoming phase
  messages from World.
- Casting gestures remain fully recognized by `RodMotionInterpreter`, but
  `RodViewModel` now suppresses `.casting` whenever the synchronized phase is
  not `.idle`.
- Rod UI now exposes the current hook phase beside the local motion phase for
  synchronization debugging.

### Verification

- `git diff --check` passes.
- No direct World hook-phase assignment remains outside
  `setHookPhase(_:)`.
- Runtime two-device transport and hook lifecycle verification remain pending
  because they require the World and Rod applications running together.

## Motion Calibration and Gesture Recognition

Design source: `CtSPoC_Motion_Calibration_and_Gesture_Recognition_Design.md`

The motion pipeline now has a Codable calibration profile between raw
CoreMotion samples and gesture validation:

```text
CoreMotion -> MotionProfile -> RodMotionInterpreter -> gameplay gate
```

- Added `MotionProfile`, `CastProfile`, `ReelProfile`, and `LiftProfile` in
  Shared with conservative defaults for first launch.
- `RodMotionInput` now carries forward user acceleration in addition to pose
  and rotation rate.
- Cast detection uses the calibrated cast pitch delta, forward acceleration,
  and calibrated gesture duration; a backward or insufficient swing is
  rejected before `RodAction.casting` is emitted.
- Reel detection uses profile-based rotation rate and maximum speed values.
- The calibrated forward acceleration sign is stored, so the same gesture can
  be recognized regardless of the device's local Z-axis direction while
  opposite-direction swings are rejected.
- The current profile is persisted in Rod `UserDefaults`; recalibrating the
  home pose updates the stored profile.
- Rod now blocks all gesture output until the neutral, cast, and reel steps
  are completed. The calibration screen is the first motion flow shown in the
  controller UI.

## Motion System Refactor

Source: `Motion System Refactor Plan` from the attached task document.

- Introduced the pure `MotionPose` value type containing only pitch, roll, and
  yaw. `RodMotionPose` remains as a compatibility typealias for existing state
  consumers.
- Rebuilt `MotionProfile` around calibrated `idlePose`, `castPose`, and
  `reelPose` values. Motion metadata is limited to the calibrated cast
  acceleration context and reel activity context.
- Rewrote `RodMotionInterpreter` to classify the current orientation by the
  closest calibrated pose. It combines that classification with acceleration
  for casting and rotation rate for reeling; it no longer compares pitch
  deltas as the primary gesture model.
- Rebuilt the visible wizard around pose capture: averaged Idle samples,
  final stable Cast samples, and averaged Reel samples. No action is emitted
  until all three poses are captured and persisted.
- Updated the secondary debug output to explain selected pose and distances to
  Idle, Cast, and Reel instead of presenting threshold checks as the primary
  decision model.
- Existing hook-phase filtering remains downstream in `RodViewModel`, so
  gameplay authority is unchanged.
- Idle reference installation now happens at the moment the Idle step is
  captured, before Cast/Reel calibration continues. Preview and post-
  calibration `RodState` therefore use the same relative frame, preventing
  the rod from snapping when calibration finishes.

### Verification

- `git diff --check` passes.
- Motion gameplay sources and Shared models were reviewed for the new profile
  contracts.
- Full SwiftPM/Xcode build remains environment-blocked by the Observation
  macro/plugin and SourcePackages permission errors; device runtime validation
  is still pending.
- Existing hook-phase gameplay validation remains in `RodViewModel`, after
  motion recognition and before transport.

### Verification

- Shared source typechecks against the macOS SDK.
- `git diff --check` passes.
- Full gesture-profile capture for cast, reel, and lift remains a follow-up
  runtime calibration flow; the profile model and validation pipeline are now
  in place.

## Motion Calibration First-Run Flow

Follow-up implementation for the calibration UX:

- Added a visible `Motion Calibration` section to the Rod view. It is the
  first motion flow shown and reports the current step and sample count.
- Calibration is now sequential: capture neutral pose, perform and capture a
  natural cast, then perform and capture a natural reel.
- `RodViewModel` collects live motion samples during the cast and reel steps,
  derives personalized pitch, acceleration, duration, rotation-rate, and
  maximum-speed values, then persists the completed profile.
- `RodMotionInterpreter` emits no casting or reeling action until the profile
  is complete. Existing profiles restore their home pose on launch.
- Recalibration resets the profile and returns the user to the neutral step.
- Forward validation preserves the calibrated acceleration sign, preventing a
  swing in the opposite direction from being treated as a cast.

### Verification

- Shared source typechecks against the macOS SDK.
- `git diff --check` passes.
- Rod `xcodebuild` project inspection is blocked by the environment's
  SourcePackages write restriction; device runtime verification remains
  pending.

## Calibration Architecture Compliance Review

Review source: `Calibration_Architecture_Refactor.md`

The review found one architectural gap in the previous implementation:
calibration had a persistent Idle pose, but the renderer still reconstructed
orientation from relative Euler values. That made `RodState` ambiguous because
the same values served gameplay-relative motion and visual orientation.

The gap is now addressed:

- Added `RodOrientation`, a normalized Codable quaternion value type in Shared,
  including inversion, multiplication, and Euler conversion at the motion
  boundary.
- `RodMotionInterpreter` stores `profile.calibrationReference` when Idle is
  captured and applies `inverse(reference) * current` on every frame.
- The corrected quaternion is emitted alongside gameplay-relative pose data
  in `RodMotionInterpretation`.
- `RodState` now carries `orientation`, which is the renderer-facing source of
  truth. Existing pitch/roll/yaw fields remain for compatibility and debug
  display.
- `WorldViewModel` now consumes only `RodState.orientation` for controller
  rotation. It does not calculate calibration offsets, inspect the profile, or
  remember calibration state.
- Idle reference installation still happens before Cast/Reel calibration, so
  calibration preview and post-finish runtime use the same corrected pipeline.

### Compliance Result

- Calibration owns reference capture and correction: compliant.
- Gameplay may consume relative pose: compliant.
- World is calibration-agnostic: compliant.
- Renderer consumes corrected orientation from `RodState`: compliant.
- Motion core targeted compilation and `git diff --check`: passed.
- Full app/device validation: pending because the local Xcode environment
  remains blocked by SourcePackages and Observation plugin permissions.

## Runtime Pipeline Investigation

Checkpoint source: `RealityKit Fishing Controller Checkpoint`, 2026-07-17.

This checkpoint validated the complete controller pipeline before continuing
motion or RealityKit changes:

```text
CMDeviceMotion -> MotionManager -> RodMotionInterpreter -> RodViewModel
             -> RodState -> Multipeer Transport -> WorldViewModel -> RealityKit
```

### Investigation Result

- Temporary logs were added at MotionManager, RodMotionInterpreter,
  RodViewModel, and WorldViewModel boundaries.
- An initial run showed only the World log with an identity orientation, which
  appeared to indicate that the Rod motion pipeline was not executing.
- That conclusion was discarded after correcting the execution environment:
  the instrumentation was attached to the wrong execution path/build.
- Rod-side logs then appeared normally. The issue was not quaternion math,
  calibration, transport, or RealityKit rendering.

### Current Status

- Motion pipeline executes.
- World update loop executes.
- Multiplayer transport is active.
- Debug infrastructure is working.
- No architecture regression was found during this investigation.

### Engineering Lesson

Runtime debugging must confirm execution before diagnosing architecture or
math. The required order is:

1. Confirm the target code is running.
2. Confirm logs execute.
3. Confirm values change.
4. Investigate math, transport, or rendering.

Temporary logs are diagnostic only and must not become a motion-system
dependency. The next movement priority remains stable Idle orientation,
relative gameplay pose, and reliable Idle/Cast/Reel action classification while
World continues to consume orientation independently.

## Cast Resolver Architecture

Design source: `Cast Resolver Architecture`, 2026-07-17.

The cast flow now separates physical motion interpretation from gameplay
translation:

```text
MotionManager -> RodMotionInterpreter -> CastSnapshot -> RodState
             -> CastResolver -> CastSolution -> World hook physics
```

### Implementation

- Added `CastVector3`, `CastSnapshot`, `CastConfig`, `CastSolution`, and
  `CastResolver` to Shared.
- Extended motion samples with angular velocity components so a cast snapshot
  contains the complete release state rather than only a magnitude.
- `RodMotionInterpreter` emits one immutable `CastSnapshot` when entering the
  casting phase. It remains responsible for motion interpretation and
  calibration, not gameplay balancing.
- `RodState` transports the optional cast snapshot to World.
- `CastResolver` derives horizontal direction from corrected orientation,
  projects away vertical aiming from direction, normalizes angular speed into
  power from `0...1`, and computes a launch angle from `CastConfig`.
- World resolves the snapshot once and uses `CastSolution` to construct the
  hook's initial horizontal and vertical velocity. World does not read
  CoreMotion or raw angular velocity.

### Verification

- Shared cast/motion core targeted compilation passed.
- `git diff --check` passes.
- Runtime two-device trajectory tuning remains pending.

## Cast Resolver Integration and Hook State Gating

Design source: `Pending Sprint Instructions - Cast Resolver Integration & Hook State Gating`, 2026-07-17.

### Cast Resolver Bridge

- `RodMotionInterpreter` still owns motion interpretation and emits an
  immutable `CastSnapshot` only when a cast is entered.
- `RodViewModel` now owns the `CastResolver` call and converts the snapshot to
  a `CastSolution` before publishing `RodState`.
- `RodState` carries the one-shot `CastSolution` and immediately populates
  `directionX`, `directionY`, `directionZ`, and normalized cast `distance` for
  the existing Controller State UI.
- World consumes the solution and no longer resolves snapshots or reads raw
  motion data. It only applies the gameplay-ready launch values to hook
  physics.

### Hook State Gating

- Added `HookPhase.allowsCasting` and `HookPhase.allowsReeling` as the single
  centralized gameplay permission rules.
- Rod casting is allowed only during `.idle`.
- Rod reeling is allowed only during `.hookInWater` or `.reeling`.
- `RodViewModel` suppresses invalid actions through these properties, so the
  controller cannot report `.reeling` while the hook phase is `.idle`.
- Existing World hook lifecycle remains authoritative and unchanged.

### Verification

- Shared sprint contracts compile with targeted `swiftc` verification.
- `git diff --check` passes.
- Controller State direction and distance now have a resolver-backed path.
- Runtime two-device cast and hook gating verification remains pending.

## Debug Cast Meter and Persistent Cast Solution

Design source: `Feature Proposal - Debug Cast Meter & Persistent Cast Solution`, 2026-07-17.

- Added `CastMeterConfig` with configurable short, medium, and long distance
  zones (`6m`, `12m`, and `18m` defaults).
- `RodViewModel` now maps resolved normalized cast power to a deterministic
  meter distance instead of deriving distance directly from raw physics.
- Added a visible Rod Cast Meter with green, yellow, and red zones plus a
  current-power indicator.
- The latest `CastSolution` is retained in `RodViewModel` and continuously
  published through `RodState`, so direction and distance remain visible after
  the one-frame cast event.
- Cast state resets only when a new cast replaces it or World reports the hook
  has returned to `.idle`.
- `RodState.distance` now uses the resolver/meter distance, while spatial
  distance remains the fallback when no cast solution is active.
- World continues to consume the persistent solution and does not calculate
  cast power, direction, or distance.

### Verification

- Shared cast/meter contracts compile with targeted `swiftc` verification.
- `git diff --check` passes.
- Runtime UI persistence and two-device meter/trajectory behavior remain
  pending hardware validation.

## Cast Meter Architecture Refactor

Design source: `Cast Meter Architecture Refactor - Single Source of Truth & World HUD`, 2026-07-17.

- Removed Cast Meter presentation and cast power/distance presentation state
  from the Rod UI.
- `CastSolution` is now the authoritative cast state carried by `RodState`.
  Rod retains no duplicate `castPower`, `castDistance`, or latest-solution
  storage outside the state it publishes.
- Added `World/World/Views/CastMeterView.swift`; World now owns the green,
  yellow, and red meter presentation and reads only
  `viewModel.rodState.castSolution`.
- The World meter performs no gameplay calculations. It displays the power and
  distance already present in `CastSolution`.
- Rod remains responsible for sensing, calibration, gesture recognition,
  CastResolver integration, and transport. World owns gameplay presentation.
- `CastSolution` remains persistent in `RodState` until a new cast replaces it
  or the hook returns to `.idle`.

### Verification

- Rod no longer references `CastMeterView`, `castPower`, `castDistance`, or a
  duplicate latest cast solution property.
- World HUD reads the single `CastSolution` state from `RodState`.
- Shared cast contracts compile with targeted `swiftc` verification.
- `git diff --check` passes.
