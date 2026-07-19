# CtSPoC Session Memory

Read this file and `AGENTS.md` before working. `CHECKPOINT.md` is the complete
history and must receive a new dated entry for every task, like a lightweight
git commit. Always update the relevant architecture/design documentation too.
Never delete previous checkpoint entries.

## Project Structure

```text
CtSPoC/
├── AGENTS.md / SESSION_MEMORY.md / CHECKPOINT.md
├── ARCHITECTURE_DECISIONS.md
├── SOFTWARE_ARCHITECTURE_DOCUMENT.md
├── SPATIAL_CONTROLLER_DOCUMENT.md
├── GAMEPLAY_ARCHITECTURE_V1.md
├── CtSPoC.xcworkspace/
├── Shared/
│   ├── Package.swift
│   └── Sources/Shared/
│       ├── Models/      # RodState, CastSolution, HookPhase, FishSpecies, network contracts
│       ├── Gameplay/    # MotionProfile, RodMotionInterpreter, CastResolver
│       ├── Debug/       # motion decisions, samples, recorder
│       ├── Protocols/   # Transport protocol
│       └── Spatial/     # session configuration
├── Rod/Rod/
│   ├── RodApp.swift / ContentView.swift
│   ├── ViewModel/RodViewModel.swift
│   ├── Sensors/         # CoreMotion and Nearby Interaction adapters
│   ├── Transport/       # Multipeer client
│   ├── Haptics/         # Core Haptics
│   └── Views/           # controller/debug views only
└── World/World/
    ├── WorldApp.swift / ContentView.swift
    ├── ViewModels/WorldViewModel.swift
    ├── Gameplay/        # FishFightController, FishCatalog, FishCatchResult, FishRecordStore
    ├── Audio/           # SoundManager, FishingSounds (ADR-040) — World-only SFX, mirrors Rod's Haptics
    ├── Transport/       # Multipeer host
    ├── Views/CastMeterView.swift, LineTensionView.swift, ResultView.swift
    └── Assets/Rod.usdz, Assets/SFX/ (ui_click.wav, cast_throw.wav, hook_splash.wav,
        fish_interested_loop.wav, fish_bite.wav, reel_loop.wav, catch_splash.wav, ambience_lake.mp3)
```

## Tech Stack

- Swift and Xcode: implementation and app targets.
- SwiftUI: Rod controls, World layout, and HUD presentation.
- CoreMotion: Rod-only device attitude, acceleration, and angular velocity.
- Nearby Interaction: Rod-only spatial distance/direction measurement.
- MultipeerConnectivity: Rod/World discovery and Codable state transport.
- RealityKit: World-only rod, hook, water, and scene rendering.
- Core Haptics: Rod-only feedback through `HapticManager` and
  `FishingHaptics`.
- AVFoundation: World-only sound effects through `SoundManager` and
  `FishingSounds` (ADR-040). Rod has no audio playback.
- Shared local Swift package: Foundation/Swift-only contracts and motion or
  gameplay translation. Never import UI, rendering, CoreMotion, NI, or haptics
  frameworks in Shared.

## Architecture Contracts

Dependencies are `Rod -> Shared <- World`; never Rod <-> World directly.
`RodState` is the transport source of truth. `RodState.orientation` is the
corrected renderer quaternion. World renders it directly and never applies
calibration offsets.

```text
CoreMotion -> MotionManager -> RodMotionInterpreter
           -> CastSnapshot -> CastResolver -> CastSolution -> RodState
           -> Multipeer transport -> WorldViewModel -> RealityKit/HUD
```

Calibration captures an Idle `RodOrientation` reference and applies
`inverse(reference) * current` every frame. Gameplay may use relative pose;
renderer orientation always comes from `RodState.orientation`.

The no-button casting phases are:

```text
Idle -> Backswing -> Charging -> ForwardSwing -> Release -> FollowThrough
```

`RodState.castPower` is live during charging and frozen at release.
`RodState.castSolution` is the persistent completed-cast state until a new cast
or `HookPhase.idle` reset.

`RodState.directionX/Y/Z` and `distance` are spatial-only values from Nearby
Interaction. Never use cast direction or distance to move the rod root. Only
the hook receives cast velocity and moves through the scene.

World's `updateRodPose()` maintains a fixed camera-relative controller offset
and applies only `RodState.orientation`. `launchHook()`, flying simulation, and
reeling own hook movement. Hook reset must not modify the rod root.

`HookPhase.allowsCasting` and `allowsReeling` are the centralized action rules.
World owns gameplay HUD and `World/Views/CastMeterView.swift`; Rod owns no
gameplay presentation.

`GAMEPLAY_ARCHITECTURE_V1.md` is the product source of truth: Rod is an input
device and World is the game. World owns the complete gameplay loop, fish
systems, tension, HUD, tutorials, results, and progression. Rod only reports
controller intent/state and renders World-directed haptics.

The follow-up architecture decision is ADR-018: gesture charging and cast
state are separate from the rod transform. `RodState.directionX/Y/Z` and
`distance` remain Nearby Interaction values. `CastSolution.direction` and
`distance` are consumed by hook simulation and the World HUD only.

Documentation-only tasks must update the relevant Markdown sources and
`CHECKPOINT.md` without changing Swift, Xcode projects, assets, or runtime
structure.

## Working Rules

1. Inspect `git status` and read relevant docs before editing.
2. Keep changes scoped and preserve unrelated user changes.
3. Use `apply_patch` for manual edits; never use destructive git commands.
4. Update the proper documentation section for every implementation change.
5. Append a commit-like dated entry to `CHECKPOINT.md` with scope, files,
   flows, verification, and remaining limitations.
6. Run `git diff --check` and targeted Shared compilation before handoff.
7. Explicitly report device/runtime validation gaps.

## Verification

```sh
cd Shared
swiftc -parse-as-library -target arm64-apple-macosx14.0 \
  -emit-module -module-name SharedMotion \
  Sources/Shared/Models/RodAction.swift \
  Sources/Shared/Models/SpatialState.swift \
  Sources/Shared/Models/HookPhase.swift \
  Sources/Shared/Models/RodState.swift \
  Sources/Shared/Debug/MotionDebugDecision.swift \
  Sources/Shared/Gameplay/MotionProfile.swift \
  Sources/Shared/Gameplay/CastResolver.swift \
  Sources/Shared/Gameplay/RodMotionInterpreter.swift \
  -o /tmp/SharedMotion.swiftmodule
git diff --check
```

Full Xcode/device validation may be blocked by local SourcePackages,
Observation plugins, simulator, signing, or hardware availability.
