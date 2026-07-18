# CtS Software Architecture Document (SAD)

## Catch the Scott - Spatial Controller PoC

Version: 1.0

# 1. Vision

Build a reusable spatial controller framework where:

-   World (macOS) hosts the RealityKit simulation.
-   Rod (iPhone) behaves as a physical controller.
-   Nearby Interaction provides relative spatial awareness.
-   CoreMotion provides orientation.
-   CoreHaptics provides feedback in later milestones.

Gameplay is intentionally excluded from Phase 1.

------------------------------------------------------------------------

# 2. Architecture

                    Shared (Swift Package)

     Models
     Protocols
     Utilities

            ▲                    ▲

            │                    │

       World (macOS)         Rod (iPhone)

     RealityKit             CoreMotion
     ViewModel              MotionManager
     NearbyInteraction      NearbyInteraction
     Transport              Transport

Dependencies:

-   World -\> Shared
-   Rod -\> Shared
-   World and Rod never depend on each other.

------------------------------------------------------------------------

# 3. Components

## Shared

Purpose: Common models, protocols and utilities.

Contains:

-   RodState
-   MotionPacket
-   SpatialState
-   Transport protocol
-   Codable helpers

Never imports: - RealityKit - CoreMotion - SwiftUI

------------------------------------------------------------------------

## World

Responsibilities

-   RealityKit rendering
-   World simulation
-   NI session
-   Receive RodState
-   Debug overlay

Folders

Reality/ Spatial/ Transport/ ViewModels/ Views/

------------------------------------------------------------------------

## Rod

Responsibilities

-   CoreMotion
-   NI session
-   Produce RodState
-   Debug overlay
-   Future haptics

Folders

Motion/ Spatial/ Transport/ Haptics/ Views/

------------------------------------------------------------------------

# 4. Data Flow

    CoreMotion
          │
          ▼
    MotionManager
          │
          ▼
    RodState
          │
          ▼
    Transport
          │
          ▼
    World
          │
          ▼
    RealityKit

Nearby Interaction updates RodState independently.

------------------------------------------------------------------------

# 5. Threading

-   UI: MainActor
-   RealityKit: MainActor
-   CoreMotion callbacks -\> isolated manager
-   Transport -\> async/await
-   Nearby Interaction delegates -\> ViewModel

------------------------------------------------------------------------

# 6. State Machine

    Idle

    ↓

    Searching

    ↓

    Connecting

    ↓

    Session Ready

    ↓

    Streaming

    ↓

    Disconnected

    ↺

------------------------------------------------------------------------

# 7. Class Responsibilities

Rod

-   MotionManager
-   NearbyInteractionManager
-   TransportClient
-   RodViewModel

World

-   NearbyInteractionManager
-   TransportHost
-   WorldViewModel
-   RealityScene

Shared

-   RodState
-   MotionPacket
-   TransportProtocol

------------------------------------------------------------------------

# 8. Error Handling

Recover from:

-   Session invalidation
-   Peer disconnect
-   Missing spatial updates
-   Motion unavailable

Always attempt reconnection.

------------------------------------------------------------------------

# 9. Coding Rules

-   MVVM only.
-   Single Responsibility Principle.
-   Shared contains platform-independent code only.
-   No singleton unless justified.
-   async/await preferred.
-   Protocol-first design.

------------------------------------------------------------------------

# Implementation Plan

## Sprint 0 - Project Foundation

-   Verify Workspace builds.
-   Verify Shared imports into both apps.
-   Remove template code.

Deliverable: Clean project.

------------------------------------------------------------------------

## Sprint 1 - Shared Package

Implement:

-   RodState
-   MotionPacket
-   SpatialState
-   TransportProtocol
-   Constants

Deliverable: Shared compiles independently.

------------------------------------------------------------------------

## Sprint 2 - Nearby Interaction

Implement:

-   NearbyInteractionManager (World)
-   NearbyInteractionManager (Rod)
-   Session lifecycle
-   Discovery exchange abstraction

Deliverable: Session established.

------------------------------------------------------------------------

## Sprint 3 - Motion

Implement:

-   MotionManager
-   Pitch
-   Roll
-   Yaw

Display locally.

Deliverable: Stable motion values.

------------------------------------------------------------------------

## Sprint 4 - Controller State

Merge:

-   Motion
-   Spatial

into RodState.

Deliverable: Single source of truth.

------------------------------------------------------------------------

## Sprint 5 - Synchronization

Stream RodState to World.

Display:

-   Distance
-   Direction
-   Pitch
-   Roll
-   Yaw

Deliverable: Both devices show synchronized values.

------------------------------------------------------------------------

## Sprint 6 - RealityKit

Create:

-   RealityScene
-   Debug cube

Cube reacts to RodState.

Deliverable: Visible motion synchronization.

------------------------------------------------------------------------

## Sprint 7 - Gesture Engine

Detect:

-   Idle
-   Cast
-   Reel

Deliverable: Discrete controller events.

------------------------------------------------------------------------

## Sprint 8 - Fishing Prototype

Implement:

-   Hook
-   Fish
-   Catch
-   Haptics

------------------------------------------------------------------------

# Agent Instructions

The implementation agent must follow these rules:

1.  Complete exactly one sprint at a time.
2.  Every sprint must compile before moving on.
3.  Never introduce gameplay before Sprint 8.
4.  Never bypass Shared models.
5.  Keep Nearby Interaction, Motion, RealityKit and Transport in
    separate modules.
6.  Prefer composition over inheritance.
7.  Use Apple's latest SDK APIs only.
8.  Write small, testable classes.
9.  Keep ViewModels free from rendering code.
10. Treat RodState as the single source of truth for controller state.

------------------------------------------------------------------------

## Calibration Orientation Pipeline

The motion system has two related outputs with separate responsibilities:

```text
Raw Device Orientation -> Calibration Reference -> Corrected RodOrientation
                                      -> RodState.orientation -> World
                                      -> Relative Motion Pose -> Gameplay
```

Rod captures and persists the Idle reference, applies
`inverse(reference) * current` on every frame, and sends the corrected result
in `RodState.orientation`. World only renders that value and must not calculate
calibration, apply offsets, remember an Idle reference, or use relative pose
for visual rotation.

------------------------------------------------------------------------

## Cast Resolver Pipeline

Cast release follows a separate gameplay translation boundary:

```text
RodMotionInterpreter -> CastSnapshot -> RodState -> CastResolver
                    -> CastSolution -> Gameplay/World Physics
```

`CastSnapshot` is immutable and contains corrected orientation, angular
velocity, and timestamp. `CastResolver` computes horizontal direction,
normalized power, and launch angle. Raw angular velocity is never exposed to
gameplay as a balancing value.

Definition of Done for each sprint:

-   Builds successfully.
-   Runs on target device(s).
-   No warnings.
-   Code reviewed for architecture.
-   Ready for the next sprint.

------------------------------------------------------------------------

## Gesture Charging and Cast Presentation

The Rod motion pipeline also publishes a charging state machine and live
normalized power. The current phase and power travel in `RodState`, allowing
World to render a live cast meter without reading CoreMotion. On release,
`CastResolver` converts the immutable snapshot into the single authoritative
`CastSolution`, which remains available for hook simulation and the release
summary.

The controller transform is spatial-only: Nearby Interaction distance and
direction position the rod root, while cast direction, power, and distance
drive the hook trajectory. World must keep the rod root stable during a cast
and move only the hook entity for cast motion.

## World Controller and Hook Separation

`WorldViewModel.updateRodPose()` is controller-only. It applies a fixed
camera-relative `controllerOffset` and the corrected `RodState.orientation`.
It does not inspect cast direction, cast distance, or hook phase.

Hook launch and simulation own all gameplay translation. The hook starts from
the rod tip, receives velocity from `CastSolution`, falls under gravity, and
reels toward the controller. The rod root remains unchanged throughout these
phases.

------------------------------------------------------------------------

## Gameplay Architecture V1

The product contract is documented in `GAMEPLAY_ARCHITECTURE_V1.md`.
World owns the complete player-facing game loop:

```text
Connect -> Calibration -> Ready -> Cast -> Hook Flying -> Splash
  -> Searching -> Interested -> Bite -> Fight -> Catch/Escape
  -> Result -> Continue/Menu
```

Rod is a minimal physical controller. It reports intent and state through
shared contracts and renders haptics requested by World. Rod must not own
gameplay HUD, fish information, tutorials, progression, or catch results.

The V1 fight mechanic is line tension, driven by rod movement, reeling, fish
resistance, and haptic rhythm. It is not a quick-time event or a generic fish
health bar. Fish selection and progression are data-driven through biome,
water type, equipment, bait, difficulty, and probability tables.

## Hook Phase Fish Grab (No Visual Fish Yet)

Recorded in ADR-023, superseding the earlier visual-first ADR-022. Before any
fish is rendered, `HookPhase` (Shared) was made to reflect whether a fish is
actually attached to the hook:

```text
idle -> flying -> hookInWater -> fishOnHook -> reeling -> idle
                (searching)      (bite)       (fight)   (catch)
```

At the time of ADR-023, `WorldViewModel` tracked bite attachment privately
(`biteTimer`, `hasFishOnHook`) rather than encoding it into `HookPhase`
itself; that state (and the escape/tension timers added next) has since
moved into `FishFightController` — see "Fish Species and Fight Simulation"
below. `fishBite` and `catchFish` were previously defined in `FishingEvent`
and already handled by `Rod/Rod/Haptics/FishingHaptics.swift`, but World
never sent them before ADR-023 — that was their first real use.

## Fish Species and Fight Simulation

Current design recorded across ADR-024, ADR-026, and ADR-028 (which
superseded ADR-024's and ADR-027's tension/escape mechanisms — see those
ADRs for the mechanisms that were tried and replaced along the way).
`World/World/Gameplay/FishFightController.swift` is an `ObservableObject`
owning all bite/fight/catch simulation; `WorldViewModel` holds none of this
state directly and drives the controller from `tick(deltaTime:)`:

```text
.hookInWater                 -> fishFight.updateSearching(deltaTime:)
  -> returns true              -> HookPhase .fishOnHook, send .fishBite
.fishOnHook / .reeling       -> reeling ? reelHook() : driftHookAway()
  (merged switch case)       -> fishFight.updateFight(deltaTime:, isReeling:, reelSpeed:)
  -> returns .escaped          -> HookPhase .hookInWater, send .fishEscaped
  -> returns .lineBreak        -> hook disabled, HookPhase .idle, send .lineBreak
reelHook() reaches rod       -> fishFight.resolveCatch(), send .catchFish
  (hasFishOnHook)
new splash                    -> fishFight.resetForNewCast()
```

`WorldViewModel` still owns `HookPhase` transitions, the hook entity, and
sending `FishingEvent` over transport; `FishFightController` has no
transport, entity, or `HookPhase` knowledge.

**Species data.** `Shared/Sources/Shared/Models/FishSpecies.swift` is a
`Codable`, Foundation-only struct (`id`, `name`, `weightRange`,
`lengthRange`, `resistance` 0...1, `value`) plus `FishSpeciesRange` (a
`Codable` min/max pair, since `ClosedRange` does not synthesize `Codable`).
It carries no mesh or asset reference. `World/World/Gameplay/
FishCatalog.swift` is the World-owned content list (`all: [FishSpecies]`,
one entry today, `"fish_a"`) and `randomSpecies()` picker; adding a species
is a one-line addition there.

**Tension safe zone — the fish physically fights back.** Matches
`GAMEPLAY_ARCHITECTURE_V1.md`'s own line-tension description: the player
keeps tension in a safe zone; sustained tension too high *or* too low
loses the fish. `FishFightController.lineTension: Float` (0...1) starts at
`initialTension` (0.5) on a bite and updates every tick in
`updateFight(deltaTime:isReeling:reelSpeed:)`:

```text
reelPull = isReeling ? reelSpeed * baseReelTensionRate(0.5) : 0
lineTension += (reelPull - effectiveFishPullRate) * deltaTime
effectiveFishPullRate = baseFishPullRate(0.15) * (1 + resistance)

lineTension <= 0 -> .escaped (line went slack)
lineTension >= 1 -> .lineBreak (reeled too hard)
```

Not reeling drains tension toward 0 (the fish is winning); reeling raises
it, and reeling too hard for too long pushes it past 1. The fish also
physically drags the hook: `FishFightController.fishPullSpeed: Float`
(species-scaled m/s, zero unless hooked) is read by
`WorldViewModel.driftHookAway(deltaTime:)`, which moves the hook entity
away from the rod along the same rod-to-hook axis
`reelHook(deltaTime:)` already uses, just reversed — the controller
publishes a speed only, it never touches RealityKit. Reeling still closes
that same distance via the existing `reelHook`/catch-distance logic, so
tension and physical hook position now move together: ignoring a hooked
fish both drains tension *and* visibly lets it swim away with the hook.
Species `resistance` scales `effectiveFishPullRate` and `fishPullSpeed`
together, so a tougher fish both drains tension faster and drags the hook
away faster when not countered.

`resistance` itself (ADR-030) is not read straight off the species — it is
scaled by how big *this* catch rolled within the species' own range, so two
fish of the same species do not fight identically:

```text
sizeRatio = clamp01((currentWeight * currentLength - minProduct)
                     / (maxProduct - minProduct))
resistance = species.resistance * sizeRatio
```

where `minProduct`/`maxProduct` are `species.weightRange.min/max *
species.lengthRange.min/max`. A catch that rolled near the species' min
weight/length fights close to the base rate; one near the max fights at
the full species `resistance`.

**Cast distance caps how big a fish can roll (ADR-031).**
`WorldViewModel` measures the real horizontal distance a cast traveled —
`simd_distance` between the hook's launch position (captured in
`launchHook(solution:)`) and its splash position (in
`simulateFlyingHook(deltaTime:)`) — and passes it to
`FishFightController.resetForNewCast(castDistance:)`. This is distinct
from `CastSolution.distance`, Rod's cast-meter estimate shown during
charging, which is not wired to launch physics. `FishFightController`
publishes it as `lastCastDistance` (shown in `ContentView`'s Controller
State grid) and uses it to cap the bite roll:

```text
sizeCeilingRatio = 0.3 + 0.7 * clamp01(castDistance / maxExpectedCastDistance)
rolledWeight/Length = random(min, min + span * sizeCeilingRatio)
```

`maxExpectedCastDistance` (10.0) is an estimate of the physics' own max
range at full charge, level release. A short cast still floors at 30% of
each range so it isn't hopeless; only a cast near max range can roll near
the species' max weight/length — and since `sizeRatio`/`resistance`
above already derive from the rolled weight/length, a far cast landing a
big fish is automatically a tougher fight too.

**Guaranteed fight distance on bite (ADR-031).** If the player was
already reeling in during the search phase, the hook can already be
within `reelHook`'s catch-distance threshold the instant a fish bites —
without a guard, the very next `reelHook` call in the same tick would
resolve an instant catch, and `hasFishOnHook` would flip `true` then
`false` before SwiftUI renders a frame, so `LineTensionView` (gated on
`hasFishOnHook`) never visibly appears. `WorldViewModel.
ensureFightDistance()`, called immediately after entering `.fishOnHook`,
pushes the hook back out to `FishFightController.minimumFightDistance`
(0.4 m) along the existing rod-to-hook axis if it's already closer,
mirroring `initialTension`'s buffer idea from ADR-028.

**Reeling with no fish stays `.hookInWater` (ADR-031).** `reelHook
(deltaTime:)` only calls `setHookPhase(.reeling)` when `fishFight.
hasFishOnHook` is true. Reeling in during `.hookInWater` before any bite
(an intentional empty-retrieve action) moves the hook and, once it's
close enough to the rod, resolves through the existing no-catch path
straight to `.idle` — it never passes through `.reeling`/`.fishOnHook`.
This matters because `tick()`'s `case .fishOnHook, .reeling:` branch
assumes a fish is attached whenever it's reached, and its not-reeling
`else` branch unconditionally sets `.fishOnHook` — without the guard,
releasing the reel gesture mid-retrieve (no bite yet) would flip
`hookPhase` to `.fishOnHook` with nothing on the line.

**HUD.** `World/World/Views/LineTensionView.swift` renders `lineTension` on
a bar with a shaded safe zone (`0.3...0.7`, green) and two failure
directions: below `0.15` shows `"LOSING FISH"`, above `0.85` shows
`"SNAPPING"`; it's visible whenever `fishFight.hasFishOnHook`.
`ContentView`'s "Catch Results" section shows `fishFight.caughtCount` and
`fishFight.lastCatchResult` (species name, weight, length,
caught/escaped/line-broke outcome) via `FishCatchResult`
(`World/World/Gameplay/FishCatchResult.swift`, HUD-only, not `Codable`/
transported). `ContentView` observes `viewModel.fishFight` as its own
`@ObservedObject` (constructed in `init()`), so `FishFightController`'s
`@Published` state drives the HUD independently of `WorldViewModel`'s.

`FishingEvent.fishEscaped` and `.lineBreak` were previously defined and
already handled by `FishingHaptics.swift`, but World never sent either
before ADR-024. `HapticManager` has a distinct `fishEscaped()` pattern
instead of aliasing to `lineBreak()`'s pattern.

## Fish Interest, Result Screen, and Rod's Minimal V1 Interface

Recorded in ADR-029.

**Fish Interest.** `HookPhase` did not gain a case for this — reeling is
already allowed throughout `.hookInWater` regardless of interest, so it is
presentation-only state layered on the existing search phase.
`FishFightController.updateSearching(deltaTime:)` returns
`SearchEvent? { .interested, .bite }`, driven by two sequential timers
(`interestTimer` then `biteTimer`, each `0.8...2.0s`) instead of one
`1.5...4.0s` timer. `isFishInterested: Bool` is `@Published` for a future
World visual cue (not built yet — fish still have no visual
representation). `FishingEvent.fishInterested` fires once when interest
starts; Rod's `FishingHaptics.interestPulse(now:)` throttles a repeating
soft haptic (`HapticManager.fishInterested()`) while an internal flag is
set, cleared by any other `FishingEvent` or by
`RodViewModel.handle(.hookPhase:)` whenever the phase leaves
`.hookInWater` (`stopInterest()`) — so a stale interest signal can't keep
pulsing after the fish bites, escapes, or a new cast begins.
`RodViewModel.updateAction()` calls `interestPulse()` unconditionally every
motion sample, reusing the same recurring callback that drives
`reelTick(reelSpeed:now:)`.

**Result Screen.** `HookPhase` gains `.result`, entered only via
`reelHook()`'s catch path (`resolveCatch()` then `.result` instead of
`.idle`), and excluded from both `allowsCasting` and `allowsReeling` so a
physical cast can't race the result screen off-screen before the player
sees it. `WorldViewModel.continueFishing()` (guarded to
`hookPhase == .result`) is the only way back to `.idle`, called by the new
`World/World/Views/ResultView.swift` overlay's "Continue Fishing" button
— "Return to Menu" from the product doc is not implemented, since there is
no Main Menu yet to return to. Escape and line-break intentionally do not
route through `.result`; they keep the direct transitions from ADR-028 —
only "After a successful catch" gets the full result treatment per the
product doc's own scoping, and gating every escape/line-break behind a
dismissable modal would make repeated near-misses tedious.

`FishCatchResult` gains `stars: Int` (1...5, from how close the catch
weight is to the species' max), `coins: Int`
(`species.value * (0.6 + 0.1 * stars)`), and `isNewRecord: Bool` — all
zero/false for non-`.caught` outcomes, computed in
`FishFightController.resolve(outcome:)` only when catching. New
`World/World/Gameplay/FishRecordStore.swift` persists the heaviest catch
per species ID to `UserDefaults` as JSON (same pattern as `RodViewModel`'s
`MotionProfile` persistence), and `recordCatch(speciesID:weight:)`'s
return value becomes `isNewRecord`.

**Rod's Minimal V1 Interface.** `Rod/Rod/ContentView.swift`'s primary view
now matches the product doc exactly: title, connection status, and three
buttons (`Start Fishing`, the per-step calibration button, `End Fishing`).
All previous debug rows move into a collapsed-by-default `DisclosureGroup`
("Developer Details") instead of being deleted, matching the existing
precedent of demoting rather than removing development tooling (e.g. the
commented-out `MotionDebugView` section). `RodViewModel` gains
`isFishing: Bool` and `startFishing()`/`endFishing()`; `startFishing()`
only takes effect once `calibrationStep == .complete`.
`updateAction()`'s existing `hookPhase.allowsCasting`/`allowsReeling` gate
gains `!isFishing` ahead of both, so cast/reel gestures are only live
between an explicit start and end rather than the moment calibration
finishes.

Known gap, not addressed this sprint: the product doc also specifies
calibration instructions belong entirely in World, with Rod only
capturing. Rod's `calibrationInstruction` text (unchanged by this sprint)
still lives on Rod — pre-existing, and tracked under the still-open World
Main Menu/Tutorial/Calibration-instructions gap.

## Dynamic Reel Speed

Recorded in ADR-025. `RodMotionInterpreter`'s `.reel` classification
previously saturated `reelSpeed` to a binary 0/1 because
`max(profile.reelRotationRate, 1)` floored the denominator to 1 while real
device rotation rates during reeling routinely exceed 1 rad/s.
`MotionProfile.reelFullRotationRate` (captured from the peak, not just the
average, rotation rate observed during reel calibration) now provides a
second reference point, and `reelSpeed` is a linear ramp between the
calibrated minimum (`reelRotationRate`, 0.0) and the player's own
demonstrated peak (`reelFullRotationRate`, 1.0). Reel speed now tracks how
fast the player actually spins the controller instead of jumping straight
to maximum.
