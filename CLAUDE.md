# CtSPoC Session Memory

Read this file before working. History, ADRs, and cross-file relationships that
used to live in `AGENTS.md`, `CHECKPOINT.md`, `ARCHITECTURE_DECISIONS.md`,
`SOFTWARE_ARCHITECTURE_DOCUMENT.md`, `GAMEPLAY_ARCHITECTURE_V1.md`, and
`Archive/` now live in a `graphify` knowledge graph instead — see
**Knowledge Graph** below. This file is the only Markdown doc kept at the
project root; it is deliberately short and durable, not a changelog.

## Project Structure

```text
CtSPoC/
├── CLAUDE.md
├── graphify-out/     # generated knowledge graph — see Knowledge Graph section
├── CtSPoC.xcworkspace/
├── Shared/
│   ├── Package.swift
│   └── Sources/Shared/
│       ├── Models/      # Device/, Gameplay/, Rod/, Spatial/ subfolders — RodState,
│       │                # CastSolution, HookPhase, FishSpecies, network contracts
│       ├── Gameplay/    # MotionProfile, RodMotionInterpreter, CastResolver
│       ├── Debug/       # motion decisions, samples, recorder
│       ├── Protocols/   # Transport protocol
│       └── Spatial/     # session configuration
├── Rod/Rod/
│   ├── RodApp.swift / ContentView.swift
│   ├── ViewModel/RodViewModel.swift, ViewModel/FishPreviewViewModel.swift
│   ├── Sensors/         # CoreMotion and Nearby Interaction adapters
│   ├── Transport/       # CoreBluetooth client (Rod = BLE peripheral)
│   ├── Haptics/         # Core Haptics
│   ├── Reality/          # FishPreviewARViewContainer — AR fish preview (Rod-only exception, see below)
│   └── Views/           # controller/debug views only
└── World/World/
    ├── WorldApp.swift / ContentView.swift
    ├── ViewModels/WorldViewModel.swift
    ├── Gameplay/        # FishFightController, FishCatalog, FishCatchResult, FishRecordStore
    ├── Audio/           # SoundManager, FishingSounds (ADR-040) — World-only SFX, mirrors Rod's Haptics
    ├── Transport/       # CoreBluetooth host (World = BLE central)
    ├── Support/         # Theme.swift — shared color/font tokens, ShadowedLabel (ADR-087)
    ├── Fonts/           # Fredoka-Regular.ttf, Fredoka-Bold.ttf (see ATSApplicationFontsPath below)
    ├── Views/CastMeterView.swift, LineTensionView.swift, ResultView.swift, CreditsView.swift,
    │   TutorialView.swift (tap-to-advance overlay shown over ContentView on first "Start Fishing")
    └── Assets/Rod.usdz, Assets/SFX/ (ui_click.wav, cast_throw.wav, hook_splash.wav,
        fish_interested_loop.wav, fish_bite.wav, reel_loop.wav, catch_splash.wav, ambience_lake.mp3,
        idle.wav, reel_fight.wav)
```

Custom fonts (`Theme.fredoka`/`fredokaBold`, ADR-087) are registered via both `UIAppFonts` (iOS) and
`ATSApplicationFontsPath` (macOS) in `World/World/Info.plist` — macOS silently ignores `UIAppFonts`,
so both keys are required for a font bundled the same way on every platform this target supports.

The 3D assets `World` loads (`World/World/Assets/Environment/*.usdz`, plus fish) are authored in a
**separate sibling repo**, `~/repos/new-blender-project` (Blender source + docs — start at its root
`CLAUDE.md`). That repo's own `.usdz` exports are the source of truth; the files under
`World/World/Assets/Environment/` are copies and must be kept byte-identical (`shasum` both sides
after any change). If a shipped asset looks visually wrong (bad lighting, missing texture,
malformed geometry) and nothing in this repo's own rendering/material code explains it, check
whether the `.usdz` itself is at fault (`unzip` it, `usdcat` the `.usdc`) before assuming an
app-side bug.

## Tech Stack

- Swift and Xcode: implementation and app targets.
- SwiftUI: Rod controls, World layout, and HUD presentation.
- CoreMotion: Rod-only device attitude, acceleration, and angular velocity.
- Nearby Interaction: Rod-only spatial distance/direction measurement. Session
  is live and data transmits, but as of ADR-041 no gameplay/rendering code
  currently reads it — the "spatial controller" aspect isn't load-bearing in
  this development phase; CoreBluetooth alone carries what V1 gameplay needs.
- CoreBluetooth: Rod/World discovery and Codable state transport (Rod = BLE
  peripheral, World = BLE central; replaced MultipeerConnectivity, ADR-035).
- RealityKit: World-only rod, hook, water, and scene rendering; also used
  Rod-side for the standalone AR Fish Preview screen (see below).
- Core Haptics: Rod-only feedback through `HapticManager` and
  `FishingHaptics`.
- AVFoundation: World-only sound effects through `SoundManager` and
  `FishingSounds` (ADR-040). Rod has no gameplay audio playback.
- Shared local Swift package: Foundation/Swift-only contracts and motion or
  gameplay translation. Never import UI, rendering, CoreMotion, NI, or haptics
  frameworks in Shared.

## Project Rules

- Dependencies: `Rod -> Shared <- World`. Never introduce a direct Rod <-> World
  dependency.
- `Shared` is platform-independent: Foundation and the Swift standard library
  only (Models, Protocols, Utilities). Never import SwiftUI, RealityKit,
  ARKit, NearbyInteraction, CoreMotion, CoreHaptics, AppKit, or UIKit there.
- `World` owns RealityKit, world state, the spatial session, and debug UI; it
  never accesses CoreMotion directly.
- `Rod` owns CoreMotion, Nearby Interaction, haptics, and controller state; it
  never contains RealityKit gameplay-rendering logic (the AR Fish Preview
  screen is a narrow, explicitly-scoped exception — see Gameplay V1 below).
- Design principles: MVVM, composition over inheritance, single-responsibility,
  protocol-oriented design, `async/await`, avoid global state and singletons
  unless technically required.
- Naming: managers (`MotionManager`, `NearbyInteractionManager`,
  `TransportHost`, `TransportClient`), view models (`WorldViewModel`,
  `RodViewModel`), models (`RodState`, `MotionPacket`, `SpatialState`),
  protocols suffixed `Protocol` (e.g. `TransportProtocol`).
- Threading: UI and view models are `@MainActor`; managers use actor isolation
  only where necessary. Never block the main thread.
- Coding style: prefer `guard`/early return, small functions, immutable
  structs. Avoid deep nesting, force unwraps, large view models, and massive
  classes. Recommended size limits: ViewModel < 300 lines, Manager < 400
  lines, View < 250 lines — refactor if you exceed them.
- Framework usage: SwiftUI, RealityKit, NearbyInteraction, CoreMotion,
  CoreHaptics, Foundation are allowed; avoid deprecated APIs and prefer
  Apple's latest SDK APIs.
- PRs must compile, have a clear description and testing notes, and avoid
  unrelated refactoring. A task is done only when it builds without errors or
  new warnings, keeps the architecture consistent, and follows these
  conventions.
- Prefer extending existing components and reusing `Shared` models over adding
  new ones. Ask for clarification rather than guessing an architectural
  decision. Keep commits small and incremental.

## Architecture Contracts

`RodState` is the transport source of truth. `RodState.orientation` is the
corrected renderer quaternion. World renders it directly and never applies
calibration offsets.

```text
CoreMotion -> MotionManager -> RodMotionInterpreter
           -> CastSnapshot -> CastResolver -> CastSolution -> RodState
           -> CoreBluetooth transport -> WorldViewModel -> RealityKit/HUD
```

Calibration is owned by the Rod motion layer and `Shared` motion models; World
must remain unaware of calibration state and must never apply a calibration
offset or reconstruct it from Euler values. Calibration captures an Idle
`RodOrientation` reference and applies `inverse(reference) * current` every
frame. `MotionPose` holds only raw pitch/roll/yaw; `RodOrientation` is the
renderer-facing normalized quaternion contract; calibration preview and
runtime consume the same corrected pipeline. Gameplay may use relative pose,
but renderer orientation always comes from `RodState.orientation`.

The no-button casting phases are:

```text
Idle -> Backswing -> Charging -> ForwardSwing -> Release -> FollowThrough
```

`RodState.castPower` is live during charging and frozen at release.
`RodState.castSolution` is the persistent completed-cast state until a new
cast or `HookPhase.idle` reset. `RodMotionInterpreter` only detects/snapshots
a cast — it must not compute distance, physics, or gameplay balancing.
`CastResolver` consumes only the immutable `CastSnapshot` and produces
`CastSolution` (direction, normalized power, launch angle); gameplay and World
physics must not read CoreMotion or raw angular velocity directly. World owns
the cast HUD and renders live power from `RodState.castPower`;
`RodState.castSolution` is the only cross-process cast result, and World must
not re-resolve a cast from sensor input.

`RodState.directionX/Y/Z` and `distance` are spatial-only values from Nearby
Interaction. Never use cast direction or distance to move the rod root. Only
the hook receives cast velocity and moves through the scene. Per ADR-041,
these NI fields are not currently consumed anywhere in gameplay or rendering
— present and transmitted, but debug-display-only for now; do not reintroduce
NI-driven rod positioning without a new ADR. Cast direction, power, and
distance must never overwrite rod spatial position or orientation.

World's `updateRodPose()` maintains a fixed camera-relative controller offset
(ADR-019) and applies only the yaw component of `RodState.orientation`
(ADR-079) — the rod root turns left/right but never tumbles on pitch/roll,
matching how a real rod moves in an angler's hands — plus a fixed,
sensor-independent `rodRestPitch` composed under that yaw so the rod reads as
diagonally held rather than flat horizontal. `updateRodPose()` may update only
that fixed offset and `RodState.orientation`; it must not read cast distance
or cast direction. `launchHook()`, flying simulation, and reeling own hook
movement. Hook reset must not modify the rod root.

`HookPhase.allowsCasting` and `allowsReeling` are the centralized action
rules. World owns gameplay HUD and `World/Views/CastMeterView.swift`; Rod owns
no gameplay presentation.

Documentation-only tasks must not change Swift, Xcode projects, assets, or
runtime structure.

## Gameplay Architecture V1

Product principle: **Rod is an input device. World is the game.** Every
future feature must preserve this. World owns the complete player-facing
experience — menu, tutorial, calibration instructions, fishing HUD, hook and
fish simulation, results, progression, and future inventory/shop/collection
systems. Rod is a minimal physical controller: motion input, calibration
capture, cast/reel intent, buttons, connection status, haptic output. Rod
must not display gameplay HUD, fish information, tutorials, progression, or
catch results.

Gameplay state machine: `Connect -> Calibration -> Ready -> Cast -> Hook
Flying -> Splash -> Searching -> Interested -> Bite -> Fight -> Catch/Escape
-> Result -> Continue/Menu`.

- Casting is a natural motion (backswing distance, then forward flick), but
  the player must press "Start Casting" first (ADR-050) to arm one attempt so
  ordinary phone movement is never misread as a cast.
- The fish fight combines physical rod movement, reeling, line tension, and
  haptic feedback, punctuated by a randomized "FLICK ROD NOW!" quick-time
  event (ADR-078) — the player flicks the rod forward before a short reaction
  window expires; success relieves tension, a miss spikes it. Line tension
  (not a health bar) is kept in a safe zone; sustained over/under-tension
  causes escape and may snap the line. Rod haptics communicate resistance
  through rhythm and intensity; World decides the gameplay event and Rod only
  renders the typed feedback.
- The catch cutscene (ADR-045–ADR-077 era) is a fixed ~5-second, non-skippable
  World presentation state: camera cuts in, the fish leaps and holds at the
  peak with a slow-motion dip, then settles, with a "CATCH!" title and HUD
  fade — before the result screen (fish name, weight, length, stars, coins,
  new-record status).
- Fish selection is data-driven: species own weight/length/resistance ranges,
  value, and difficulty; biome, water type, equipment, bait, and difficulty
  feed a probability table. Equipment tier unlocks larger fish pools.
- **Exception (ADR-121, ADR-122):** Rod hosts a standalone AR Fish Preview
  screen (`FishPreviewView`/`FishPreviewViewModel`) letting the player inspect
  a species they've already caught, entirely outside the live
  Connect->Cast->Catch loop. Confirmed by the user as Rod-only and scoped to
  already-caught species only — not a gameplay HUD, not reachable mid-session,
  and not a channel for World to push live gameplay/progression state onto
  Rod. The one-way sync backing it (`NetworkMessage.caughtSpecies`,
  World -> Rod) only tells Rod which species are unlocked for this
  out-of-session screen. This is not license to route HUD, tension, tutorial,
  or result-screen content onto Rod elsewhere.

V1 is complete when the full loop works end to end: Rod connects, the player
calibrates and casts naturally, the hook lands and fish selection runs, a fish
may bite and fight with meaningful tension and dynamic haptics, the fish is
caught or escapes, World shows the result, and the player can immediately cast
again.

## Knowledge Graph

Full project history — every dated checkpoint entry and every ADR (currently
ADR-001 through ADR-139) with their cross-references, plus a code-relationship
graph over `Shared`/`Rod`/`World` — has been extracted into a `graphify`
knowledge graph at `graphify-out/`, generated by the `graphify` CLI
(`uv tool install graphifyy`; https://github.com/Graphify-Labs/graphify) using
its `claude-cli` backend (shells out to the local `claude` command, no API key
needed).

- `graphify-out/graph.json` — the full queryable graph (1343 nodes, 2422
  edges, 147 communities as of the 2026-07-31 build).
- `graphify-out/GRAPH_REPORT.md` — human-readable summary: community hubs, god
  nodes, hyperedges (grouped ADR chains like the flick/QTE redesign or the
  fishing-line/rope debugging saga), ambiguous edges worth reviewing.
- `graphify-out/graph.html` — interactive visualization.

Useful commands (run from the repo root, `graphify` on `PATH` via
`~/.local/bin`):

```sh
graphify query "<question>"           # BFS traversal answer, budget-capped
graphify explain "ADR-078"            # plain-language node + neighbors
graphify path "RodState" "WorldViewModel"   # shortest path between two nodes
graphify god-nodes                    # most-connected architectural hubs
```

Keep the graph fresh instead of writing new prose docs:

```sh
graphify update .                                    # code changes only, no LLM/cost
graphify extract . --backend claude-cli --force       # after doc-worthy changes (new ADR-equivalent decisions, etc.)
graphify cluster-only . --backend claude-cli          # regenerate GRAPH_REPORT.md/community labels after extract
```

`graphify check-update .` reports whether the graph is stale relative to the
current commit. There is no more `CHECKPOINT.md` to hand-append — record
significant decisions by re-running `graphify extract` so they become graph
nodes, and note anything not obviously captured (a rationale, a rejected
alternative) directly in code comments or PR descriptions instead.

## Working Rules

1. Inspect `git status` before editing.
2. Keep changes scoped and preserve unrelated user changes.
3. Never use destructive git commands.
4. Update this file when architecture contracts or working rules change; keep
   the knowledge graph current per the commands above instead of writing new
   root-level Markdown docs.
5. Run `git diff --check` and targeted Shared compilation before handoff.
6. Explicitly report device/runtime validation gaps.

## Verification

```sh
cd Shared && swift build
git diff --check
```

`Shared`'s sources are organized into `Models/{Device,Gameplay,Rod,Spatial}/`, `Gameplay/`, `Debug/`,
`Protocols/`, and `Spatial/` — use `swift build` (reads `Package.swift`) rather than hardcoding a file
list here, since individual model files have moved between subfolders as the package grew.

Full Xcode/device validation may be blocked by local SourcePackages,
Observation plugins, simulator, signing, or hardware availability.
