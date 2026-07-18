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

## Casting Architecture Documentation Audit

Added the follow-up contract to the project guidance and architecture docs:

- `AGENTS.md` now requires charging phase/power ownership in Rod/Shared,
  World-owned HUD presentation, and strict separation between spatial rod
  transforms and cast gameplay values.
- `ARCHITECTURE_DECISIONS.md` records ADR-018 for gesture charging and the
  stationary rod root/hook-only cast movement decision.
- `Software_Architecture_Document_and_Implementation_Plan.md` documents the
  live charging pipeline, persistent `CastSolution`, and transform boundary.
- `SESSION_MEMORY.md` records the same contracts for terminal-based session
  handoff.

Verification: targeted Shared compilation and `git diff --check` pass. Full
Xcode/device validation remains pending local build dependencies and hardware.

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

## Casting Architecture Follow-up

Design source: `Casting Architecture Follow-up - Gesture Charging, World HUD, and Rod Transform Separation`, 2026-07-18.

### Gesture Charging

- Added motion phases for `backswing`, `charging`, `forwardSwing`, `release`,
  and `followThrough`.
- `RodMotionInterpreter` reports live normalized cast power during the casting
  gesture and freezes release power during FollowThrough.
- `RodState` transports `motionPhase` and `castPower` so World can animate a
  live HUD without reading CoreMotion.
- `CastSolution` remains created only at release and remains the frozen
  gameplay cast state.

### World HUD

- World Cast Meter consumes `RodState.motionPhase`, `RodState.castPower`, and
  `RodState.castSolution`.
- The meter is visible during charging/release phases and displays frozen
  solution values during release/follow-through.
- Rod remains free of gameplay HUD presentation.

### Rod Transform Separation

- `RodState.directionX/Y/Z` and `distance` now remain spatial-only.
- World positions the rod from spatial state, while hook physics uses only
  `CastSolution` direction, power, distance, and launch angle.
- Hook and rod remain separate scene entities; casting/reeling changes only
  hook position and velocity.

### Verification

- Shared charging/cast contracts compile with targeted `swiftc` verification.
- `git diff --check` passes.
- Full two-device charging HUD and stationary-rod runtime validation remains
  pending hardware execution.

## Session Memory Restoration

Restored `SESSION_MEMORY.md` after it was absent from the working tree. The
memory now includes the complete project structure, tech stack, gesture
charging phases, corrected calibration pipeline, CastSolution ownership,
World HUD ownership, stationary-rod invariant, documentation rules, and
targeted verification commands.

## Terminal Session Memory

Added `SESSION_MEMORY.md` as the compact handoff document for local
terminal-based AI sessions. It summarizes project boundaries, source-of-truth
contracts, calibration and CastResolver flow, HookPhase rules, UI ownership,
verification commands, current feature state, and documentation entry points.

The memory file now also documents the technology stack and complete project
structure, including the responsibilities of SwiftUI, RealityKit, CoreMotion,
Nearby Interaction, MultipeerConnectivity, Core Haptics, and the Shared local
Swift package.

The session workflow now explicitly requires every task to update the proper
architecture/design documentation and append a new `CHECKPOINT.md` entry in a
git-commit-like format covering scope, file/flow changes, verification, and
remaining limitations. Previous checkpoint history must remain intact.

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

## Gameplay Architecture V1 Documentation Update

Design source: `Catch the Scott - Gameplay Architecture V1`, 2026-07-18.

Documentation-only update. No Swift, Xcode project, asset, or runtime
structure was modified.

- Added `GAMEPLAY_ARCHITECTURE_V1.md` as the product and gameplay source of
  truth.
- Documented the core principle: Rod is an input device and World is the game.
- Defined World ownership of menus, tutorials, calibration guidance, HUD,
  hook/fish simulation, line tension, results, and progression.
- Defined Rod's minimal V1 surface: motion, calibration, cast/reel intent,
  buttons, connection status, and haptic output.
- Documented the complete gameplay loop from connection through catch/escape,
  result, and continuing fishing.
- Added the fish-interest, bite, fight, line-tension, haptic-rhythm, fish
  selection, and equipment progression contracts.
- Updated AGENTS, architecture decisions, software architecture, spatial
  controller architecture, and terminal session memory to reference the V1
  contract and documentation-only workflow.

Verification: confirmed the change set contains Markdown files only and
`git diff --check` passes. Code compilation was intentionally not run because
this task explicitly requested documentation changes only.

## World Controller and Hook Architecture Refactor

Design source: `World Controller & Hook Architecture Refactor`, 2026-07-18.

Investigation found `WorldViewModel.updateRodPose()` positioning `RodRoot`
with `RodState.direction * distance`, which made the controller behave like a
cast projectile. The implementation now:

- keeps `RodRoot` at a fixed camera-relative offset;
- applies only `RodState.orientation` in `updateRodPose()`;
- removes controller dependence on cast direction and cast distance;
- keeps `CastSolution` consumption inside hook launch velocity calculation;
- preserves hook-only movement for flight, splash, reeling, and reset;
- removes the unused rod-origin calculation from hook launch.

Architecture documentation now records ADR-019 and updates AGENTS, the
implementation plan, and session memory with the controller/hook ownership
boundary.

Verification: `git diff --check` and targeted Shared compilation pass. Full
Xcode/device runtime validation remains pending because local package
resolution and simulator services are unavailable in this environment.

## Documentation Errata and Dead Code Cleanup

Date: 2026-07-18.

Follow-up housekeeping after a full-repository review. Content under
`Architecture /` is treated as a development log and is not required to track
current implementation state; only a genuine indexing error was corrected
there. The remaining work removed code paths with no live callers.

### Documentation

- Renumbered the duplicate `ADR-014 --- Debug First` to `ADR-021` in
  `ARCHITECTURE_DECISIONS.md` (it collided with the existing
  `ADR-014 --- Nearby Interaction Ownership`). No other content in that file,
  `SOFTWARE_ARCHITECTURE_DOCUMENT.md`, or `SPATIAL_CONTROLLER_DOCUMENT.md` was
  changed; their drift against the current `RodState` shape and folder layout
  is accepted as historical log content.

### Dead Code Removed

- Deleted `Shared/Sources/Shared/Models/PeerInfo.swift` and
  `Shared/Sources/Shared/Models/MotionPacket.swift`: neither type had any
  remaining reference outside their own declaration.
- Deleted `Shared/Sources/Shared/Debug/MotionRecording.swift`: the file
  contained only a header comment, no implementation.
- Removed `NetworkMessage.hello` and `NetworkMessage.motion` cases; both were
  never constructed anywhere in Rod or World, and `RodViewModel`'s message
  switch only ever discarded them. `RodViewModel.handle(_:)` now matches only
  the remaining unhandled case, `.state`.
- Removed `WorldViewModel.loadRodEntity()`: an alternate Rod.usdz loading path
  superseded by `makeArrow()`/`makeSceneEntity()`, never called.
- Removed `WorldViewModel.modelPitch/modelYaw/modelRoll` and
  `updateModelOrientation()`, and the `#if DEBUG` `orientationSlider(_:value:)`
  helper in `World/ContentView.swift` that only existed to drive those
  properties. None of this was reachable from the current view body.
- Gated remaining development `print()` diagnostics behind `#if DEBUG` in
  `Rod/Rod/Transport/TransportClient.swift`,
  `World/World/Transport/TransportHost.swift`, and
  `Rod/Rod/ViewModel/RodViewModel.swift`, so they no longer compile into
  release builds. Also removed a stale commented-out alternate
  `didNotStartAdvertisingPeer` implementation in `TransportHost.swift`.

### Explicitly Out of Scope

Per direction, the commented-out `MotionDebugView` section in
`Rod/ContentView.swift` and the commented-out `CastMeterView` section in
`World/ContentView.swift` were left untouched — both are fully implemented
and considered intentionally disabled rather than dead.

### Verification

- Targeted Shared compilation (`swiftc -parse-as-library`, full model set
  including `NetworkMessage`) passes with no errors or warnings.
- `git diff --check` passes.
- `grep` confirms no remaining references to `PeerInfo`, `MotionPacket`,
  `MotionRecording`, `loadRodEntity`, `updateModelOrientation`,
  `modelPitch`/`modelYaw`/`modelRoll`, or `orientationSlider` anywhere in the
  Swift sources.
- Full Xcode/device build remains environment-blocked as in prior checkpoints.

## Gameplay V1 - Fish Spawn (Fish A)

Date: 2026-07-18.

Design source: `GAMEPLAY_ARCHITECTURE_V1.md`, first implementation slice
requested for the fish system, scoped to spawning a single fish entity.
Recorded as ADR-022 in `ARCHITECTURE_DECISIONS.md`.

### Scope

- Added `World/World/Gameplay/FishManager.swift`, a `@MainActor` manager that
  owns one `ModelEntity` named `"Fish A"`: spawn, despawn, and idle swim
  motion. It is World-only; Rod and Shared are untouched.
- The fish body is a `ModelEntity` sphere mesh (`generateSphere`) scaled
  non-uniformly (`[1, 0.6, 2.2]`) to approximate an elongated fish shape,
  since this RealityKit SDK has no capsule mesh primitive and no fish asset
  exists yet. Matches the existing primitive-mesh convention used for the rod
  arrow and hook.
- `WorldViewModel` now holds `sceneRoot` (captured at the end of
  `makeSceneEntity()`) and a `FishManager` instance created in `init()` with
  the existing `waterHeight`.
- `setHookPhase(_:)` calls `fishManager.spawn(in: sceneRoot)` when the phase
  transitions from `.flying` to `.hookInWater`, and `fishManager.despawn()`
  when the phase returns to `.idle`. `tick(deltaTime:)` calls
  `fishManager.update(deltaTime:)` every frame; the update is a no-op while
  no fish is spawned.
- Fish A swims in a slow circular idle loop around a randomized point in the
  water plane, chosen at spawn time, and orients to face its direction of
  travel. There is no searching, fish interest, bite, fight, or species data
  yet — those remain future work per `GAMEPLAY_ARCHITECTURE_V1.md`.

### Documentation

- `CLAUDE.md` project structure now lists
  `World/World/Gameplay/FishManager.swift`.
- Added ADR-022 to `ARCHITECTURE_DECISIONS.md` (Fish Spawn Ownership).
- Added a "Fish Spawn (Fish A)" subsection to the "Gameplay Architecture V1"
  section of `SOFTWARE_ARCHITECTURE_DOCUMENT.md`.

### Verification

- `xcrun swiftc -typecheck` on `FishManager.swift` standalone passes (no
  Shared dependency; imports only `RealityKit` and `simd`).
- Targeted Shared `swiftc -parse-as-library` compilation (per the standard
  verification command set) passes.
- `git diff --check` passes.
- `WorldViewModel.swift` remains at 289 lines, under the 300-line ViewModel
  guideline in `AGENTS.md`.
- Full Xcode/device build and in-scene visual verification remain
  environment-blocked, as in prior checkpoints; the fish spawn/despawn/swim
  behavior has not been observed running.

## Gameplay V1 - Hook Phase Fish Grab (Reverted Visual Fish)

Date: 2026-07-18.

Direction change from the prior entry, the same day: no visual fish in
World for now. Priority is making `HookPhase` actually reflect the real
game state (e.g. a fish grab) before any rendering. Recorded as ADR-023 in
`ARCHITECTURE_DECISIONS.md`, which marks ADR-022 as superseded rather than
deleting it.

### Scope

- Deleted `World/World/Gameplay/FishManager.swift` and its directory. No
  fish entity, mesh, or RealityKit visual exists in World anymore.
- Reverted `WorldViewModel`'s `sceneRoot`/`fishManager` wiring added for the
  visual slice.
- Added `HookPhase.fishOnHook` in
  `Shared/Sources/Shared/Models/HookPhase.swift`, between `hookInWater` and
  `reeling`. `allowsReeling` now includes `.fishOnHook`.
- `WorldViewModel` now tracks fish attachment as private simulation state
  (`biteTimer: Float`, `hasFishOnHook: Bool`), not as part of `HookPhase`
  itself:
  - `updateBiteTimer(deltaTime:)` runs every tick while `.hookInWater`;
    on expiry (`biteTimer <= 0`) it sets `hasFishOnHook = true`, transitions
    to `.fishOnHook`, and sends `FishingEvent.fishBite`.
  - `tick(deltaTime:)` gained a `.fishOnHook` case (reels like
    `.hookInWater`) and the `.reeling` case now returns to `.fishOnHook`
    instead of unconditionally `.hookInWater` when `hasFishOnHook` is true.
  - `simulateFlyingHook()` resets `hasFishOnHook = false` and
    `biteTimer = Float.random(in: 1.5...4.0)` on every splash, so each cast
    gets an independent, randomized chance to hook a fish.
  - `reelHook(deltaTime:)` sends `FishingEvent.catchFish` only when the hook
    reaches the rod with `hasFishOnHook == true`, then clears the flag; an
    empty retrieve from `.hookInWater` (never bitten) sends no event.
- `FishingEvent.fishBite` and `.catchFish` were already defined and already
  handled by `Rod/Rod/Haptics/FishingHaptics.swift`, but World never sent
  either one before this change — this is their first real use.
- Explicitly not implemented yet: fish interest (as distinct from bite),
  line tension, escape (`fishEscaped`/`lineBreak` remain unsent), species
  data, and any visual/RealityKit representation of a fish. A bite always
  succeeds if reeled in.

### Documentation

- `CLAUDE.md` project structure reverted (no `Gameplay/FishManager.swift`
  entry).
- `ARCHITECTURE_DECISIONS.md`: ADR-022 marked Superseded by new ADR-023
  (Hook Phase Reflects a Real Fish Grab, No Visual Fish Yet). Neither ADR
  entry was deleted.
- `SOFTWARE_ARCHITECTURE_DOCUMENT.md`: replaced the "Fish Spawn (Fish A)"
  subsection with "Hook Phase Fish Grab (No Visual Fish Yet)" describing the
  new state machine.

### Verification

- Targeted Shared `swiftc -parse-as-library` compilation, expanded to
  include `FishingEvent.swift`, `NetworkMessage.swift`, `ConnectionState.swift`,
  `SpatialStatus.swift`, and `Transport.swift` alongside the standard set,
  passes with no errors.
- `grep` confirms `WorldViewModel.swift`'s `switch hookPhase` is the only
  exhaustive switch over `HookPhase` in the repository, and it already
  handles `.fishOnHook`.
- `git diff --check` passes.
- Full Xcode/device build and in-scene/haptic runtime verification remain
  environment-blocked; the bite/catch event flow and Rod haptic response
  have not been observed running end to end.

## Gameplay V1 - Escape/Line-Break Haptics and Dynamic Reel Speed

Date: 2026-07-18.

Confirmed on-device: hook/fish-bite/reel now work end to end (prior
checkpoint entry's flow was validated). This entry covers two follow-ups
raised from that test: (1) `fishEscaped`/`lineBreak` haptics were defined
but never triggered by any real game state, and (2) `RodState.reelSpeed`
read as a constant 1.000 or 0.000 instead of scaling with how fast the
player physically rotates the controller. Recorded as ADR-024 and ADR-025
in `ARCHITECTURE_DECISIONS.md`.

### Fish Escape and Line Break (ADR-024)

- `World/World/ViewModels/WorldViewModel.swift` gained `biteExpireTimer`,
  `lineStrainTimer`, and constants `biteExpireDuration` (2.5s),
  `lineBreakReelThreshold` (0.9 reel speed), `lineBreakSustainDuration`
  (1.2s).
- `updateBiteExpiry(deltaTime:)` runs while `.fishOnHook` and the player is
  not reeling; on expiry it clears `hasFishOnHook`, returns `HookPhase` to
  `.hookInWater` with a fresh `biteTimer`, and sends
  `FishingEvent.fishEscaped`.
- `updateLineStrain(deltaTime:)` runs while `.reeling` with
  `hasFishOnHook == true`; it accumulates only while
  `rodState.reelSpeed >= lineBreakReelThreshold` and resets to zero
  otherwise. Sustaining the threshold for `lineBreakSustainDuration`
  disables the hook, clears `hasFishOnHook`, returns `HookPhase` to `.idle`,
  and sends `FishingEvent.lineBreak`.
- Pausing reeling mid-fight (the `.reeling` case's `else` branch) now resets
  `biteExpireTimer` to `biteExpireDuration` before returning to
  `.fishOnHook`, so the escape clock doesn't keep draining silently through
  a reel/pause boundary.
- `simulateFlyingHook()` resets both new timers to zero alongside the
  existing `hasFishOnHook`/`biteTimer` reset on every splash.
- `Rod/Rod/Haptics/HapticManager.swift` gained `fishEscaped()`, a fading
  three-pulse pattern distinct from the sharp single-transient
  `lineBreak()`. `Rod/Rod/Haptics/FishingHaptics.swift`'s `handle(_:)` no
  longer aliases `.fishEscaped` to `.lineBreak`'s haptic; each case now maps
  to its own method.

### Dynamic Reel Speed (ADR-025)

- Root cause: `RodMotionInterpreter`'s `.reel` case computed
  `speed = min(1, rotationRateMagnitude / max(profile.reelRotationRate, 1))`.
  `reelRotationRate` (the calibrated minimum threshold) is almost always
  under 1.0, so `max(_, 1)` floored the denominator at a near-constant `1`,
  and real reeling motion easily exceeds 1 rad/s — so `speed` saturated to
  `1.0` almost immediately past the detection threshold.
- `Shared/Sources/Shared/Gameplay/MotionProfile.swift`: added
  `reelFullRotationRate: Double` alongside the existing `reelRotationRate`.
- `Shared/Sources/Shared/Gameplay/RodMotionInterpreter.swift`: `.reel` now
  computes
  `speed = clamp((rotationRateMagnitude - reelRotationRate) / (reelFullRotationRate - reelRotationRate), 0...1)`,
  a continuous ramp instead of a saturating ratio.
- `Rod/Rod/ViewModel/RodViewModel.swift`'s reel-calibration step
  (`calibrateMotion()`, `.reel` branch) now also records `peakRate` (the max
  rotation rate magnitude across the demonstrated reel samples, not just
  the average) and sets
  `reelFullRotationRate = max(reelRotationRate + 0.3, peakRate)`. The
  player's own demonstrated peak becomes the 1.0 reference instead of an
  arbitrary constant.
- `MotionProfile` is `Codable` and persisted via `UserDefaults`;
  `RodViewModel.loadMotionProfile()` already uses `try?` around decode, so a
  profile saved before this change safely falls back to requiring
  recalibration rather than crashing.

### Verification

- Targeted Shared `swiftc -parse-as-library` compilation (standard set plus
  `FishingEvent`, `NetworkMessage`, `ConnectionState`, `SpatialStatus`,
  `Transport`) passes.
- Built `Shared` as an iOS-simulator module
  (`-sdk iphonesimulator -target arm64-apple-ios17.0-simulator`) and used it
  to `swiftc -typecheck` `Rod/Rod/Haptics/FishingHaptics.swift`,
  `Rod/Rod/Haptics/HapticManager.swift`, and the full
  `Rod/Rod/ViewModel/RodViewModel.swift` alongside its sibling sensor/
  transport files (`MotionManager.swift`, `NearbyInteractionManager.swift`,
  `TransportClient.swift`) — all pass with no errors.
- `git diff --check` passes.
- Full Xcode/device build remains environment-blocked; the escape/
  line-break event flow, the two new haptic patterns, and the dynamic reel
  speed feel have not been observed running on hardware yet.

## Gameplay V1 - FishSpecies Model, Continuous Line Tension, Catch HUD

Date: 2026-07-18.

Follow-up requested after confirming the escape/line-break/reel-speed work:
(1) a real 0...1 tension bar instead of the prior binary sustained-threshold
timer, (2) World HUD showing catch success and running catch count, and (3)
fish separated into their own data model so species can carry base
modifiers and be swapped for real assets later. Recorded as ADR-026 in
`ARCHITECTURE_DECISIONS.md`.

### FishSpecies Data Model

- Added `Shared/Sources/Shared/Models/FishSpecies.swift`: `Codable`,
  `Sendable`, `Identifiable` struct (`id`, `name`, `weightRange`,
  `lengthRange`, `resistance: Double` 0...1, `value: Int`), plus
  `FishSpeciesRange` (a `Codable` min/max pair — `ClosedRange` does not
  synthesize `Codable`, so it can't be used directly in a `Codable` model).
  No mesh, asset name, or RealityKit reference; Shared still imports only
  Foundation.
- Added `World/World/Gameplay/FishCatalog.swift`: the World-owned content
  list (`static let all: [FishSpecies]`, currently one entry, `"fish_a"` /
  "Fish A") and `randomSpecies()`. Adding a species means appending one
  entry here; nothing else in the fight simulation is species-specific
  code, only data.

### FishFightController (Extracted From WorldViewModel)

- Added `World/World/Gameplay/FishFightController.swift`, a `@MainActor`
  `ObservableObject` owning all fish-fight state: `hasFishOnHook`,
  `lineTension: Float` (`@Published`, 0...1), `caughtCount`,
  `lastCatchResult: FishCatchResult?`, plus the private bite/escape timers
  and the currently-hooked species/weight/length.
- `WorldViewModel.tick(deltaTime:)` now calls into it instead of managing
  bite/escape/tension timers inline:
  `updateSearching(deltaTime:)`, `updateWaiting(deltaTime:)`,
  `pauseFight()`, `updateFighting(deltaTime:reelSpeed:)`, `resolveCatch()`,
  `resetForNewCast()`. `WorldViewModel` still owns `HookPhase` transitions,
  the hook entity, and sending `FishingEvent`; the controller has no
  transport, entity, or `HookPhase` knowledge.
- `lineTension` replaces the prior `lineStrainTimer`/threshold/sustain-
  duration mechanic (ADR-024) with a continuous value: it rises while
  reeling above a per-species safe reel speed
  (`effectiveSafeReelSpeed`) at a per-species rate
  (`effectiveTensionRiseRate`), decays otherwise, and breaks the line at
  1.0. Species `resistance` also scales the bite grace period
  (`effectiveBiteExpireDuration`) — a stronger fish gives less time to
  react to a bite and snaps the line faster under strain.
- `World/World/Gameplay/FishCatchResult.swift`: a small, non-`Codable`,
  World-only struct (`speciesName`, `weight`, `length`,
  `outcome: .caught/.escaped/.lineBreak`) used purely for HUD display, set
  by `FishFightController` whenever a bite resolves.

### World HUD

- Added `World/World/Views/LineTensionView.swift`: a green/yellow/red
  0...1 bar bound to `fishFight.lineTension`, visible whenever
  `fishFight.hasFishOnHook`; shows a "SNAPPING" label past 0.8.
- `World/World/ContentView.swift` now constructs `WorldViewModel` in an
  explicit `init()` and separately observes `viewModel.fishFight` as its
  own `@ObservedObject`, so `FishFightController`'s `@Published` state
  drives the view independently of `WorldViewModel`'s. Added a "Catch
  Results" `GroupBox` showing `fishFight.caughtCount` and the last resolved
  outcome (species name, weight in kg, length in cm, and
  caught/escaped/line-broke label).

### Documentation

- `CLAUDE.md`: `Shared/Models` note now mentions `FishSpecies`;
  `World/World` structure now lists `Gameplay/` (FishFightController,
  FishCatalog, FishCatchResult) and `LineTensionView.swift`.
- `ARCHITECTURE_DECISIONS.md`: added ADR-026.
- `SOFTWARE_ARCHITECTURE_DOCUMENT.md`: replaced the stale
  `WorldViewModel`-owned bite-timer description (now moved) and the ADR-024
  binary-timer section with a single "Fish Species and Fight Simulation"
  section describing the current design.

### Unrelated Concurrent Change Observed

- While this task was in progress, `Shared/Sources/Shared/Models/` was
  reorganized into subfolders (`Device/`, `Gameplay/`, `Rod/`, `Spatial/`)
  outside of this session's edits (some of it already `git add`-staged).
  This was left untouched — it did not originate from this task, and
  Swift Package Manager does not care about subfolder layout within a
  target's source directory, so it does not affect anything above.
  `FishSpecies.swift` was added directly to `Shared/Sources/Shared/Models/`
  (not into any of those subfolders) and remains there.

### Verification

- Rebuilt the Shared package as a macOS module and as an iOS-simulator
  module directly from `find Sources/Shared -name "*.swift"` (so the
  in-flight subfolder reorganization above didn't require hardcoded
  paths); both build cleanly.
- `xcrun swiftc -typecheck -target arm64-apple-macosx15.0` against the
  macOS Shared module for `WorldViewModel.swift`, `ContentView.swift`,
  `FishCatalog.swift`, `FishCatchResult.swift`, `FishFightController.swift`,
  `LineTensionView.swift`, `CastMeterView.swift`, and `TransportHost.swift`
  passes with no errors (one pre-existing, unrelated warning about an
  unused `controllerEntity` binding in `launchHook(solution:)`).
- `xcrun swiftc -typecheck -sdk iphonesimulator -target
  arm64-apple-ios17.0-simulator` against the iOS Shared module for
  `RodViewModel.swift`, `FishingHaptics.swift`, `HapticManager.swift`,
  `MotionManager.swift`, `NearbyInteractionManager.swift`, and
  `TransportClient.swift` passes with no errors.
- `git diff --check` passes.
- Full Xcode/device build and the actual on-screen tension bar/catch HUD
  have not been observed running yet.

## Gameplay V1 - Line Tension Tracks Fight Duration, Not Reel Speed

Date: 2026-07-18.

Requested change to the tension meter added in the previous entry: sync it
to reel *time* instead of reel speed, so reeling for too long automatically
maxes the meter and breaks the line (failed catch), regardless of how fast
or slow the player reels. Recorded as ADR-027 in `ARCHITECTURE_DECISIONS.md`
(amends ADR-026's tension formula only).

### Change

- `World/World/Gameplay/FishFightController.swift`:
  `updateFighting(deltaTime:reelSpeed:)` is now
  `updateFighting(deltaTime:)` — the `reelSpeed` parameter and the
  safe-speed/decay comparison are gone. `lineTension` now accumulates as
  `lineTension += deltaTime / effectiveMaxFightDuration`, capped at 1;
  reaching 1 still resolves `.lineBreak` exactly as before.
- Removed `baseSafeReelSpeed`, `baseTensionRiseRate`, `tensionDecayRate`,
  and their `effectiveSafeReelSpeed`/`effectiveTensionRiseRate` computed
  properties. Added `baseMaxFightDuration: Float = 6.0` and
  `effectiveMaxFightDuration = max(2.0, baseMaxFightDuration * (1 -
  resistance * 0.5))` — a per-species total fight-time budget instead of a
  per-species safe reel speed.
- Tension no longer has a decay branch: it only changes while
  `WorldViewModel.tick(deltaTime:)` is actively calling `updateFighting`
  (i.e. `HookPhase == .reeling` and the player is reeling), so pausing
  freezes the meter rather than draining it. The separate
  `biteExpireTimer`/escape-clock behavior (`pauseFight()`,
  `updateWaiting(deltaTime:)`) is unchanged.
- `World/World/ViewModels/WorldViewModel.swift`'s call site updated to
  `fishFight.updateFighting(deltaTime: deltaTime)` (dropped the
  `reelSpeed: rodState.reelSpeed` argument).
- No HUD changes: `LineTensionView` and the "Catch Results" section already
  just read `fishFight.lineTension`/`hasFishOnHook`/`caughtCount`/
  `lastCatchResult`, so they needed no changes for this swap.

### Documentation

- `ARCHITECTURE_DECISIONS.md`: added ADR-027, explicitly scoped as
  amending only ADR-026's tension formula (the `FishSpecies` model,
  `FishCatalog`, `FishFightController` extraction, and HUD from ADR-026
  are unaffected and not re-described).
- `SOFTWARE_ARCHITECTURE_DOCUMENT.md`: updated the "Continuous line
  tension" paragraph under "Fish Species and Fight Simulation" to describe
  the duration-based formula and reference both ADRs.

### Verification

- Rebuilt the Shared package as a macOS module directly from
  `find Sources/Shared -name "*.swift"` and used it to
  `xcrun swiftc -typecheck -target arm64-apple-macosx15.0` against
  `WorldViewModel.swift`, `ContentView.swift`, `FishCatalog.swift`,
  `FishCatchResult.swift`, `FishFightController.swift`,
  `LineTensionView.swift`, `CastMeterView.swift`, and `TransportHost.swift`
  — passes with no errors (same pre-existing unrelated `controllerEntity`
  unused-binding warning as before, not touched by this change).
- `git diff --check` passes.
- Full Xcode/device build and the actual on-device feel of a fixed 6-second
  (species-scaled) fight window have not been observed running yet.

## Gameplay V1 - Unified Tension Safe Zone, Fish Physically Fights Back

Date: 2026-07-18.

On-device testing surfaced two problems with the previous entry's design:
the tension bar never changed while the rod was idle, and the fish escaped
on a flat ~2.5s timer with no connection to anything the player could see
happening — not the fish pulling the hook away, as expected. Re-reading
`GAMEPLAY_ARCHITECTURE_V1.md`'s own "Line Tension" section confirmed the
intended V1 mechanic was already specified there: a single tension bar with
a safe zone, where tension too low *or* too high loses the fish. This
entry replaces the two separate, simpler mechanisms built across ADR-023/
024/026/027 with that one mechanism. Recorded as ADR-028 in
`ARCHITECTURE_DECISIONS.md` (marks ADR-024 and ADR-027 superseded).

### FishFightController Rewrite

- `World/World/Gameplay/FishFightController.swift`: removed
  `updateWaiting(deltaTime:)`, `pauseFight()`, `biteExpireTimer`,
  `baseBiteExpireDuration`, `effectiveBiteExpireDuration`,
  `updateFighting(deltaTime:)`, `baseMaxFightDuration`,
  `effectiveMaxFightDuration` — all replaced by one method,
  `updateFight(deltaTime:isReeling:reelSpeed:) -> FightFailure?`, called
  every tick while `hasFishOnHook` (both `.fishOnHook` and `.reeling`
  `HookPhase`s):
  - `reelPull = isReeling ? reelSpeed * baseReelTensionRate(0.5) : 0`
  - `lineTension += (reelPull - effectiveFishPullRate) * deltaTime`,
    clamped `0...1`
  - `effectiveFishPullRate = baseFishPullRate(0.15) * (1 + resistance)`
  - `lineTension <= 0` resolves `.escaped`; `lineTension >= 1` resolves
    `.lineBreak`.
- Added `FishFightController.FightFailure` (`.escaped`/`.lineBreak`), the
  return type of `updateFight`.
- `updateSearching(deltaTime:)` now sets `lineTension = initialTension`
  (0.5) on a bite instead of leaving it at 0, so the player has room to
  react in either direction from the start.
- Added `fishPullSpeed: Float` (species-scaled m/s, `0` when no fish is
  hooked) — the only new surface exposed to `WorldViewModel`. The
  controller still has zero knowledge of RealityKit, entities, or
  positions; it only publishes a speed.

### WorldViewModel: the Fish Physically Drags the Hook

- `World/World/ViewModels/WorldViewModel.swift`: merged the `.fishOnHook`
  and `.reeling` `tick(deltaTime:)` switch cases into one
  (`case .fishOnHook, .reeling:`), since both now run the same
  reel-or-drift-plus-tension-update logic and only differ in which the
  player is currently doing.
- Added `driftHookAway(deltaTime:)`: while a fish is hooked and the player
  isn't reeling, moves `hookEntity` away from the rod along the existing
  rod-to-hook axis (the same vector `reelHook(deltaTime:)` already
  computes, just negated), scaled by `fishFight.fishPullSpeed`. Reeling
  still closes that same distance via the unchanged `reelHook`/
  catch-distance logic — so a hooked fish now visibly swims away with the
  hook when ignored, and reeling visibly pulls it back.
- Added `resolveFightFailure(_:)`, reacting to
  `FishFightController.FightFailure`: `.escaped` returns `HookPhase` to
  `.hookInWater` (hook stays in the water, keeps fishing) and sends
  `.fishEscaped`; `.lineBreak` disables the hook, returns `HookPhase` to
  `.idle` (recast required), and sends `.lineBreak` — the same
  event-sending shape `reelHook`'s catch path already had.

### HUD: Safe Zone Made Visible

- `World/World/Views/LineTensionView.swift`: the bar now shades a visible
  safe zone (`0.3...0.7`, green-tinted) instead of a single green-to-red
  ramp that only made sense for a one-directional failure. Below `0.15`
  shows a `"LOSING FISH"` warning; above `0.85` still shows `"SNAPPING"`.
  Added `"Slack"`/`"Snap"` end labels, matching `CastMeterView`'s
  `"Near"`/`"Far"` caption convention.
- No changes needed to `ContentView`'s "Catch Results" section or how it
  observes `fishFight` — both already just read the published state.

### Documentation

- `ARCHITECTURE_DECISIONS.md`: added ADR-028; marked ADR-024 and ADR-027
  "Superseded by ADR-028" in place (their bodies kept intact for history,
  per the project's no-delete convention for past decisions).
- `SOFTWARE_ARCHITECTURE_DOCUMENT.md`: rewrote "Fish Species and Fight
  Simulation" to describe the current (ADR-028) design directly rather than
  layering another "amends the previous section" paragraph on top of two
  prior rewrites of the same section.

### Verification

- Rebuilt the Shared package as a macOS module directly from
  `find Sources/Shared -name "*.swift"` and used it to
  `xcrun swiftc -typecheck -target arm64-apple-macosx15.0` against
  `WorldViewModel.swift`, `ContentView.swift`, `FishCatalog.swift`,
  `FishCatchResult.swift`, `FishFightController.swift`,
  `LineTensionView.swift`, `CastMeterView.swift`, and `TransportHost.swift`
  — passes with no errors (same pre-existing, unrelated `controllerEntity`
  unused-binding warning as every prior entry in this series).
- `git diff --check` passes.
- Full Xcode/device build remains environment-blocked; the actual feel of
  the tug-of-war (reel-to-hold-steady vs. drift-away-when-idle) and the new
  safe-zone HUD have not been observed running yet.

## Gameplay V1 Sprint - Result Screen, Rod Minimal UI, Fish Interest

Date: 2026-07-18.

Sprint scoped from a gap analysis against `GAMEPLAY_ARCHITECTURE_V1.md`
requested earlier the same day ("apalagi yang belom ke develop dari
architecture plan v1 itu?"). This entry develops the top three items:
result screen, Rod's minimal production UI, and the Fish Interested phase.
Recorded as ADR-029 in `ARCHITECTURE_DECISIONS.md`.

### Shared

- `Shared/Sources/Shared/Models/Gameplay/HookPhase.swift`: added `.result`
  — excluded from both `allowsCasting` and `allowsReeling`, entered only
  after a catch, exited only via `WorldViewModel.continueFishing()`.
- `Shared/Sources/Shared/Models/Gameplay/FishingEvent.swift`: added
  `.fishInterested`, sent once when a fish becomes interested but hasn't
  bitten.

### World: Fish Interest

- `World/World/Gameplay/FishFightController.swift`: `updateSearching
  (deltaTime:)` now returns `SearchEvent? { .interested, .bite }` instead
  of `Bool`, driven by two sequential `0.8...2.0s` timers (`interestTimer`
  then `biteTimer`) replacing the single `1.5...4.0s` timer, keeping total
  time-to-bite in roughly the same range. Added
  `isFishInterested: Bool` (`@Published`, reset alongside the rest of the
  fight state in `resetForNewCast()` and `resolve(outcome:)`).
- `World/World/ViewModels/WorldViewModel.swift`'s `.hookInWater` tick case
  now switches on the `SearchEvent?` and sends `.fishInterested` or
  `.fishBite` accordingly.

### World: Result Screen

- `World/World/Gameplay/FishCatchResult.swift`: added `stars: Int`,
  `coins: Int`, `isNewRecord: Bool` (zero/false unless `.caught`).
- `World/World/Gameplay/FishFightController.swift`'s `resolve(outcome:)`
  computes them only for `.caught`: `stars` from how close the catch
  weight is to the species' max (1...5), `coins` from
  `species.value * (0.6 + 0.1 * stars)`, `isNewRecord` from the new
  `FishRecordStore`.
- Added `World/World/Gameplay/FishRecordStore.swift`: persists the
  heaviest catch per species ID to `UserDefaults` as JSON (same pattern as
  `RodViewModel`'s `MotionProfile` persistence); `FishFightController`
  now takes one as an injectable dependency (defaulting to a real store).
- `World/World/ViewModels/WorldViewModel.swift`: `reelHook()`'s catch path
  now transitions to `.result` instead of `.idle` when a fish was caught
  (empty retrieves still go straight to `.idle`, unchanged). Added
  `continueFishing()`, guarded to `hookPhase == .result`, returning to
  `.idle`. `tick()`'s switch gained `case .result: break` (must be
  exhaustive over the expanded `HookPhase`).
- Added `World/World/Views/ResultView.swift`: full-screen overlay (species
  name, weight, length, 1-5 star row, coins, optional "NEW RECORD" badge,
  "Continue Fishing" button). "Return to Menu" from the product doc is not
  implemented — no Main Menu exists yet.
- `World/World/ContentView.swift`: `body` split into a `ZStack` of the
  existing `content` plus a conditional `ResultView` shown when
  `hookPhase == .result`.
- Escape and line-break deliberately do **not** route through `.result`
  — they keep the direct transitions from ADR-028. This is scoped
  narrower than the product doc's loop diagram on purpose: the diagram's
  full result content is described in prose as following "a successful
  catch" specifically, and gating every escape/line-break behind a
  dismissable modal would make repeated near-misses tedious given there's
  currently no cooldown between bites. The inline "Catch Results" HUD row
  still surfaces those outcomes without blocking play.

### Rod: Minimal V1 Interface

- `Rod/Rod/ViewModel/RodViewModel.swift`: added `isFishing: Bool`
  (`@Published private(set)`) and `startFishing()`/`endFishing()`.
  `startFishing()` only takes effect once `calibrationStep == .complete`.
  `updateAction()`'s existing `hookPhase.allowsCasting`/`allowsReeling`
  gate gained a leading `!isFishing` condition, so cast/reel gestures are
  only live between an explicit start and end, not the instant calibration
  finishes.
- `Rod/Rod/ContentView.swift` rewritten: primary view is now title,
  connection status, and exactly three buttons (`Start Fishing`, the
  existing per-step calibration button, `End Fishing`), matching
  `GAMEPLAY_ARCHITECTURE_V1.md`'s Rod interface. All previous debug rows
  (connection/spatial/motion status, calibration step/samples, raw
  pitch/roll/yaw/action/reelSpeed/etc.) moved into a `DisclosureGroup`
  ("Developer Details"), collapsed by default, rather than being deleted —
  same precedent as the existing commented-out `MotionDebugView` section.
- **Known gap, not addressed this sprint:** the product doc specifies
  calibration instructions belong entirely in World; Rod's
  `calibrationInstruction` text (unchanged by this sprint) still lives on
  Rod. Pre-existing, not introduced here — tracked under the still-open
  World Main Menu/Tutorial/Calibration-instructions gap.

### Rod: Periodic Interested Haptic

- `Rod/Rod/Haptics/HapticManager.swift`: added `fishInterested()`, a
  single soft transient (`0.22`/`0.15`), deliberately duller than
  `fishBite()`'s four-pulse pattern.
- `Rod/Rod/Haptics/FishingHaptics.swift`: added `interestPulse(now:)`,
  throttled to `1.1s` (same throttle idiom as the existing
  `reelTick(reelSpeed:now:)`), a no-op unless an internal
  `isFishInterested` flag is set. `handle(.fishInterested)` sets it; every
  other `FishingEvent` case clears it. Added `stopInterest()` for an
  external clear.
- `RodViewModel.handle(_:)`'s `.hookPhase(phase)` case now calls
  `fishingHaptics.stopInterest()` whenever `phase != .hookInWater`, so a
  stale interest signal can't keep pulsing after the fish bites, escapes,
  or a new cast begins. `updateAction()` calls `interestPulse()`
  unconditionally every motion sample — the same recurring callback that
  already drives `reelTick`.

### Documentation

- `CLAUDE.md`: `World/World` structure now lists `FishRecordStore` under
  `Gameplay/` and `ResultView.swift` under `Views/`.
- `ARCHITECTURE_DECISIONS.md`: added ADR-029.
- `SOFTWARE_ARCHITECTURE_DOCUMENT.md`: added "Fish Interest, Result
  Screen, and Rod's Minimal V1 Interface" between the existing "Fish
  Species and Fight Simulation" and "Dynamic Reel Speed" sections.

### Verification

- Standard verification command from `CLAUDE.md` (`swiftc -parse-as-library`
  over the fixed Shared model/gameplay file list) passes.
- Rebuilt Shared as a macOS module and separately as an iOS-simulator
  module, both directly from `find Sources/Shared -name "*.swift"`, and
  used them to `xcrun swiftc -typecheck`:
  - macOS: `WorldViewModel.swift`, `ContentView.swift`, `FishCatalog.swift`,
    `FishCatchResult.swift`, `FishFightController.swift`,
    `FishRecordStore.swift`, `LineTensionView.swift`, `ResultView.swift`,
    `CastMeterView.swift`, `TransportHost.swift` — no errors (same
    pre-existing, unrelated `controllerEntity` unused-binding warning as
    every prior entry in this series).
  - iOS simulator: `RodViewModel.swift`, `ContentView.swift`,
    `FishingHaptics.swift`, `HapticManager.swift`, `MotionManager.swift`,
    `NearbyInteractionManager.swift`, `TransportClient.swift` — no errors,
    no warnings.
- `git diff --check` passes.
- Full Xcode/device build remains environment-blocked. None of the new
  UI (Rod's minimal buttons, the result screen, the interested haptic
  pulse) has been observed running on hardware yet.
