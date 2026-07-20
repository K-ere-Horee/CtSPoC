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
-   Sound effects (ADR-040)

Folders

Audio/ Reality/ Spatial/ Transport/ ViewModels/ Views/

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

The original Sprint 0-8 roadmap (project foundation through fishing
prototype) shipped long ago and has been moved to
`Archive/COMPLETED_SPRINT_ROADMAP.md` for historical reference. The project
is now in ongoing Gameplay V1 refinement; see `CHECKPOINT.md` and
`ARCHITECTURE_DECISIONS.md` for current state.

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
velocity, timestamp, and (ADR-032) `backswingDistance`: the peak angular
distance from the calibrated idle pose reached during the gesture's
backswing, tracked by `RodMotionInterpreter` and reset whenever a fresh
cast gesture begins. `CastResolver` computes horizontal direction, launch
angle, and normalized power. Raw angular velocity is never exposed to
gameplay as a balancing value on its own — power is a blend where
backswing distance is the base (zero backswing means zero power
regardless of flick speed) and release-moment flick speed only adds up to
a 30% bonus on top:

```text
power = distancePower * (0.7 + 0.3 * flickPower)
```

This mirrors how a real rod loads on the backswing and releases on the
forward snap, and fixes a reported bug where cast power tracked only how
fast the phone was flicked at release, ignoring how far back it was
pulled beforehand. `RodMotionInterpreter`'s live `castPower` (the
charging-phase meter) approximates the same blend locally so the
on-screen meter reflects what the eventual release will produce;
`CastResolver`, driven by `CastConfig`'s `minimum`/`maximumCastVelocity`
and `minimum`/`maximumBackswingDistance`, remains the single
authoritative calculation that becomes the transmitted `CastSolution.
power`.

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

**Nearby Interaction's spatial distance/direction are not read here, or
anywhere else in gameplay (ADR-041).** Rod still owns and runs the NI session
(ADR-014) and `RodState.directionX/Y/Z`/`distance` still transmit every
sample, but a full code audit found zero gameplay, rendering, or
connection-gating consumer of those fields — `updateRodPose()`'s fixed offset
above is the rod's actual, sole position source, not live NI ranging. This
was accurate up through ADR-018, but ADR-019 deliberately decoupled the rod
root from live spatial data (to fix the rod visibly moving during a cast),
and nothing since has restored NI to a load-bearing role. The plumbing is
intact for a future feature that needs real physical proximity; V1 fishing
gameplay never ended up needing it — CoreBluetooth transport alone carries
everything the current gameplay loop uses.

Hook launch and simulation own all gameplay translation. The hook starts from
the rod tip, receives velocity from `CastSolution`, falls under gravity, and
reels toward the controller. The rod root remains unchanged throughout these
phases.

**Launch heading comes from live rig geometry, not `CastSolution.direction`
(ADR-033).** `CastResolver` (Shared) computes `direction` by rotating a
fixed, mesh-agnostic reference vector — Shared has no knowledge of whatever
rig World happens to render, and must not. World's rendered rig can (and,
across the asset-integration merge, did) have a completely different local
"tip" axis than that reference assumes, which silently misaims every cast by
a fixed offset. `WorldViewModel.launchHook(solution:)` therefore derives the
horizontal launch heading itself, live, from
`tipEntity.position(relativeTo: nil) - controllerEntity.position` at the
moment of launch — correct by construction, since it's just "wherever the
rendered tip currently is relative to the fixed rod root," independent of
any particular rig's rest-pose axis convention. Only the heading is
re-derived this way; `solution.power`, `launchAngle`, and `distance` still
come from `CastSolution` unchanged.

**Launch heading is clamped to a forward cone (ADR-034).** Whatever
horizontal heading the derivation above produces, `launchHook(solution:)`
clamps it into `castConeHalfAngle` (67.5°, i.e. a 135° total cone) of the
camera's fixed forward direction *at launch time* before using it — the
launch computation itself always uses the constant `(0, 0, -1)` reference
regardless of the camera's live orientation, so `atan2(direction.x,
-direction.z)` giving the signed angle from straight ahead is safe even
though the camera can move afterward (see below). This is a deliberate
outcome guarantee independent of whether the upstream aim derivation is
fully correct — a cast can never land behind or far to the side of the
player, regardless of rig geometry quirks.

**`aimCorrectionAngle` rotates the raw aim before clamping (ADR-034).**
Live testing (via the camera-follow debug aid below) showed the raw
rig-derived aim consistently biased left of the player's true intended
heading — every cast was landing outside the cone and pinning at its
left edge, which also explained a sharp, consistent drop in cast
distance versus before the clamp existed. `rotatedAroundY(_:by:)` applies
a simple Y-axis rotation to `rawHorizontal` before it reaches
`clampedToForwardCone`, so the corrected heading falls inside the cone
as intended rather than constantly hitting its boundary. An initial 90°
guess (from the symptom alone) still landed pinned at the cone boundary,
which a clamped landing coordinate can't diagnose further — a dedicated
debug angle readout (`debugRawAimDegrees`/`debugCorrectedAimDegrees`,
unclamped, exposed below the clamp) measured the true raw bias at
**-174°**, close to a full inversion rather than a quarter turn.
`aimCorrectionAngle` is now `.pi` (180°) — a single tunable constant,
still empirical rather than derived from rig geometry, with a small ~6°
residual pending the next live reading.

**Camera follows the hook.** `WorldViewModel.updateCameraFollow()`,
called every `tick()`, swings `playerCamera` to trail behind/above the
hook and look directly at it while `hookPhase` is `.flying`,
`.fishOnHook`, or `.reeling`, snapping back to the normal fixed player
pose (`resetCameraToPlayerPose(_:)`) in every other phase. Began as a
flight-only debug aid; promoted to intended player-facing behavior for
the whole cast-and-fight arc by ADR-039 ("biar proses reel nya jadi
lebih dramatis"). Does not affect the launch-heading clamp above, since
that's computed once at launch before the hook (and camera) start
moving.

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
  (merged switch case)       -> fishFight.updateFight(deltaTime:, isReeling:, reelSpeed:, hookDistance:)
  -> returns .escaped          -> hook disabled, HookPhase .idle, send .fishEscaped (ADR-039)
  -> returns .lineBreak        -> hook disabled, HookPhase .idle, send .lineBreak
reelHook() reaches rod       -> fishFight.resolveCatch(), send .catchFish,
  (hasFishOnHook)               beginCatchCutscene(), HookPhase .result (ADR-045)
catch cutscene ends           -> hook disabled, isShowingCatchCutscene = false, ResultView shown
new splash                    -> fishFight.resetForNewCast()
```

`WorldViewModel` still owns `HookPhase` transitions, the hook entity, and
sending `FishingEvent` over transport; `FishFightController` has no
transport, entity, or `HookPhase` knowledge.

**Species data.** `Shared/Sources/Shared/Models/FishSpecies.swift` is a
`Codable`, Foundation-only struct (`id`, `name`, `weightRange`,
`lengthRange`, `resistance` 0...1, `value`, `tier` — see ADR-037) plus
`FishSpeciesRange` (a `Codable` min/max pair, since `ClosedRange` does not
synthesize `Codable`). It carries no mesh or asset reference. `World/World/
Gameplay/FishCatalog.swift` is the World-owned content list (`all:
[FishSpecies]`, one per tier as of ADR-037) and `randomSpecies
(unlockedTiers:)` picker, filtered by `ProgressionStore.unlockedTiers`;
adding a species is a one-line addition there.

**Tension safe zone — the fish physically fights back.** Matches
`GAMEPLAY_ARCHITECTURE_V1.md`'s own line-tension description: the player
keeps tension in a safe zone; sustained tension too high *or* too low
loses the fish. `FishFightController.lineTension: Float` (0...1) starts at
`initialTension` (0.5) on a bite and updates every tick in
`updateFight(deltaTime:isReeling:reelSpeed:hookDistance:)`:

```text
reelPull = isReeling ? reelSpeed * config.baseReelTensionRate(0.55) : 0
lineTension += (reelPull - effectiveFishPullRate) * deltaTime
effectiveFishPullRate = config.baseFishPullRate(0.15)
                         * (1 + resistance * config.pullRateResistanceMultiplier(3.0))

hookDistance > fightStartDistance + effectiveEscapeAllowance -> .escaped (too much line — ADR-039)
effectiveEscapeAllowance = max(config.minEscapeDistanceAllowance(2 m),
                                config.escapeDistanceAllowance(6 m)
                                  - resistance * config.escapeAllowanceResistancePenalty(3.5))
lineTension <= 0 -> .escaped (line went slack)
lineTension >= 1 -> .lineBreak (reeled too hard)

Either .escaped case -> hook disabled, HookPhase .idle (a fresh cast is required —
                          ADR-039's revision; previously only .lineBreak did this)
```

All the named constants above (`initialTension`, `baseFishPullRate`,
`baseReelTensionRate`, `pullRateResistanceMultiplier`, `basePullSpeed`,
`pullSpeedResistanceMultiplier`, `escapeDistanceAllowance`,
`escapeAllowanceResistancePenalty`, `minEscapeDistanceAllowance`, and the
tension-band thresholds/haptic parameters below) live in `FishFightConfig`
(Shared, new) — see "Fish Fight Tuning Config" below.

Not reeling drains tension toward 0 (the fish is winning); reeling raises
it, and reeling too hard for too long pushes it past 1. The fish also
physically drags the hook: `FishFightController.fishPullSpeed: Float`
(species-scaled m/s, `config.basePullSpeed(0.7) * (1 + resistance *
config.pullSpeedResistanceMultiplier(1.8))`, zero unless hooked) is read
by `WorldViewModel.driftHookAway(deltaTime:)` while the player rests, and
— ADR-039's tug-of-war — *subtracted from the player's reel speed inside
`reelHook(deltaTime:)`* while reeling: a net-negative speed moves the hook
away even mid-reel, so a strong fish gains line against weak reeling and
can win outright via the distance escape above. The controller publishes
a speed only, it never touches RealityKit. Tension and physical hook
position move together: ignoring a hooked fish drains tension *and* lets
it swim away; over-reeling snaps the line; under-reeling loses the
tug-of-war.

**Reel-in and drift-away stay at water height until near the dock (ADR-042).**
Both `reelHook`/`driftHookAway` branch on horizontal (X/Z) distance to a target
point: beyond `hookLiftDistance` (1.0 m) the hook is pinned to `waterHeight` and
moves horizontally only, so it reads as sliding across the water's surface;
within that distance, movement switches to full 3D so the hook rises the rest
of the way up.

**Inside the lift zone, the climb is a guaranteed fixed speed, not tug-of-war
(ADR-044).** Outside `hookLiftDistance`, `reelHook` still uses ADR-039's
tug-of-war (`rodState.reelSpeed * reelSpeed` net `fishFight.fishPullSpeed`),
which can stall or go negative against a strong fish — intentional for the
open-water fight. Carried into the lift zone, though, that let the hook stall
or sink back toward the water right at the dock's edge, reading as the fish
"floating" instead of being landed. Inside the zone, `reelHook` instead always
advances at a fixed `dockLiftSpeed` (3.5 m/s, faster than the player's own max
reel speed), ignoring `fishFight.fishPullSpeed` entirely — a fish this close
can no longer meaningfully resist. `driftHookAway` (used only while the player
isn't actively reeling) is unchanged and still lets an escaping fish pull the
hook back down out of the lift zone via `fishFight.fishPullSpeed`.

`reelHook`'s catch/empty-retrieve resolution now checks full 3D distance to
`hookLiftTargetPosition` (0.15 m) rather than horizontal distance (previously
0.12 m, ADR-043) — since the climb above is fast and guaranteed rather than
tug-of-war-gated, resolution can afford to wait for the hook to actually finish
arriving instead of firing while it's still mid-climb.

**That target is `hookLiftTargetPosition`, not the rod's render anchor (ADR-043).**
`hookLiftTargetPosition` (`[0.22, 1.95, -4.7]`) shares `dockAnchorPosition`'s X/Y
but not its Z — loading `dock_main.usdz` directly and measuring its
`visualBounds` put `dockAnchorPosition`'s XZ well inside the dock's own solid
footprint (X in `[-2.04, 2.04]`, Z in `[-4.5, 4.5]`), so lifting toward it rose
the hook straight up through the deck geometry. `hookLiftTargetPosition` moves
Z to `-4.7`, just past the mesh's measured water-facing edge, so the rise
happens in open space in front of the dock instead of inside it.
`dockAnchorPosition`/`controllerEntity` remain the rendering anchor for the held
rod (`updateRodPose()`) and for `ensureFightDistance()` (ADR-031) — only the
reel/drift motion and catch-distance math in `reelHook`/`driftHookAway` target
the new point.

**Catch resolution plays a cutscene before `ResultView`, as `WorldViewModel`
presentation state, not a new `HookPhase` (ADR-045).** On a real catch (not an
empty retrieve), `reelHook`'s `distance3D > 0.15` guard now calls
`fishFight.resolveCatch()` and `beginCatchCutscene(from:)` instead of disabling
`hookEntity` outright, while still setting `HookPhase` to `.result`
immediately — casting/reeling stay locked for the whole cutscene exactly as
before, since `.result` already disallows both. `isShowingCatchCutscene`
(`@Published`, `WorldViewModel`) and a private `CatchCutscene { origin,
elapsed }` struct drive `hookEntity` through a placeholder three-phase
vertical motion inside `tick(deltaTime:)`'s `.result` case — ease up to
`catchCutsceneJumpHeight` (0.6 m) over `catchCutsceneRiseDuration` (0.35 s),
hold motionless there for `catchCutsceneFreezeDuration` (0.9 s, ADR-047 — so
the moment reads as a deliberate pause, not a quick blip through the peak),
then ease back down over `catchCutsceneSettleDuration` (0.35 s) — then disable
the hook and flip the flag back to `false`. `ContentView` shows a new `CatchCutsceneView`
("CATCH!" title) while the flag is set, and `ResultView`'s condition gained
`!isShowingCatchCutscene` so the two never overlap. `HookPhase`
(`Shared`) is unchanged — the cutscene is pure `World` presentation with no
distinct input-locking or haptic behavior beyond what `.result` already
provides, so it needed no `Shared`/`Rod` changes, consistent with "Rod owns no
gameplay presentation." The jump itself is an explicit placeholder — `hookEntity`
is still the same sphere referenced throughout ADR-042 through ADR-044, and
there is no separate fish mesh anywhere in this codebase — `updateCatchCutscene
(deltaTime:)` is the intended single replacement point once a real fish
mesh/animation lands.

**The catch cutscene cuts the camera to the hook (ADR-046).**
`updateCameraFollow()` gained a first branch: while `isShowingCatchCutscene` is
true, the camera looks at `hookEntity` from a dedicated, tighter offset
instead of the mid-fight trailing `followOffset` (`[0, 1.5, 3.0]`, ADR-039) —
a deliberate "cut to the catch" shot, not the same framing the fight itself
already uses. Before this, `.result` was excluded from `followsHook`'s phase
list, so the jump played entirely off-camera from the fixed player POV. Once
the cutscene ends, the function falls through to its prior behavior
unchanged — the camera resets to the player pose for the rest of `.result`
(the stat-card wait), exactly as before ADR-046.

**The cutscene gained a camera push-in, letterboxing, HUD hide, and a title
flourish for more drama (ADR-048).** The single static camera offset from
ADR-046 (now `catchCutsceneCameraEndOffset`) is the *end* of an eased
(`smoothstep`) dolly from a new, wider `catchCutsceneCameraStartOffset`
(`[0, 1.2, 2.4]`) over `catchCutsceneTotalDuration` — a computed property
summing the three ADR-047 phase durations, so camera and hook motion can't
disagree on the cutscene's length. `CatchCutsceneView` gained top/bottom
letterbox bars that slide in on appear, a background vignette, a radial glow
behind the title, and a lower-damping spring on the title's entrance so it
visibly overshoots before settling (a "pop" instead of a flat fade-in).
`ContentView`'s stat HUD (`LineTensionView`, the caught-count/level
`GroupBox`) now fades out while `isShowingCatchCutscene` is true, so it
doesn't visually compete with the cutscene — `RealityView` and its
fps/connection overlay are unaffected. All four are presentation-only
additions layered on top of ADR-045/046/047's existing trigger/phase/camera
structure, which is otherwise unchanged. A catch sound cue was already in
place before any of this cutscene work — `reelHook`'s `emit(.catchFish)`
plays `catch_splash.wav` at the exact moment the cutscene begins — so no
audio changes were needed.

`resistance`'s contribution to `effectiveFishPullRate`/`fishPullSpeed`/
the escape allowance is scaled by its own multiplier per formula
(`pullRateResistanceMultiplier`/`pullSpeedResistanceMultiplier`/
`escapeAllowanceResistancePenalty`) rather than being added in directly
— added in this pass (ADR-039) after the original 1.0/0.5 implicit
multipliers produced too small a spread between species/tiers to feel
different (a `baseFishPullRate` floor that dominated `resistance`'s
contribution). At `resistance == 0` every species is identical (a small
individual is weak regardless of species, unchanged); at a max-size roll
the multipliers now produce a real difficulty curve across `fish_a` ->
`fish_b` -> `fish_c` -> `scott`.

**Tension-band haptics (ADR-039).** `FishFightController.tensionBand`
(`nil` outside a fight; below `config.tensionBandMediumThreshold` is low,
below `config.tensionBandHighThreshold` is medium, at/above it is high)
is watched by `WorldViewModel.syncTensionBand()` every tick, which sends
`FishingEvent.reelTensionLow/Medium/High` only on band *transitions* —
never streaming raw tension over the reliable World→Rod path. Rod's
`FishingHaptics` stores the band and pulses continuously at the band's
config-driven rhythm (default spaced 0.5 s / regular 0.28 s / rapid
0.11 s taps, intensity rising with the band), driven by the same
every-motion-sample callback as the interest pulse and cleared by
fight-ending events plus a `stopFight()` guard on `HookPhase` leaving the
fight phases. This is the product doc's "resistance through rhythm as
well as intensity" spec, keyed to live fight state rather than static
fish size.

**Fish Fight Tuning Config (ADR-039).**
`Shared/Sources/Shared/Gameplay/FishFightConfig.swift` collects every
number above — line-tension constants, the three resistance multipliers,
the distance-escape allowance, the two tension-band thresholds, and all
nine Rod haptic-band parameters (interval/intensity/sharpness ×
low/medium/high) — into one `Codable`/`Equatable` struct, each field
documented inline, meant to be hand-edited directly rather than read as
opaque defaults. `FishFightController.init`
and `FishingHaptics.init` both take `config: FishFightConfig =
FishFightConfig()`; existing zero-argument call sites are unaffected, and
both classes read the *same* config values so World's simulated
difficulty and Rod's haptic rhythm can't drift apart. `maxExpectedCastDistance`
stayed a private `FishFightController` constant — it's cast physics tied
to `WorldViewModel.castSpeed`, not fight tuning.

**Fight camera (ADR-039).** `updateCameraFollow()` tracks the hook
through `.flying`, `.fishOnHook`, and `.reeling` — the whole cast and
fight are watched up close — snapping back to the fixed player pose in
every other phase.

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
`World/World/Views/ResultView.swift` overlay's "Continue Fishing" button.
"Return to Menu" was initially left unimplemented here since no Main Menu
existed yet to return to — see ADR-036, where it was added alongside the
Main Menu itself. Escape and line-break intentionally do not
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
Tutorial/Calibration-instructions gap (Main Menu itself is no longer part
of this gap — see ADR-036).

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

------------------------------------------------------------------------

## CoreBluetooth Transport (ADR-035)

`TransportProtocol`/`NetworkMessage` (Shared) are unchanged; only what implements the protocol
changed. `TransportClient` (Rod) and `TransportHost` (World) are full CoreBluetooth rewrites,
replacing MultipeerConnectivity entirely — no `import MultipeerConnectivity` remains in either
target.

**Roles**, preserving the previous client/host split: Rod is the BLE **peripheral**
(`CBPeripheralManager`) — it advertises and pushes data, the "active broadcaster" role World's
`Rod is an input device` framing already implies. World is the BLE **central**
(`CBCentralManager`) — it scans, connects, and reacts.

**GATT layout** (UUIDs as plain `String`s in `SessionConfiguration`, Shared — not `CBUUID`, so
Shared stays free of a CoreBluetooth import):

```text
Rod (peripheral)                                    World (central)
  state characteristic     --- notify,   unreliable --->   (.state, ~30 Hz)
  reliableOut characteristic --- indicate, reliable  --->   (.discoveryToken)
  command characteristic   <--- write-with-response, reliable ---   (.hookPhase / .fishingEvent)
```

World writing into a characteristic Rod exposes is the only way a BLE central can push data to a
peripheral — there is no "central notifies" primitive, which is why the World → Rod direction is
a write rather than mirroring Rod's notify/indicate.

**Framing.** `Shared/Sources/Shared/Protocols/BLEFraming.swift` prefixes an encoded
`NetworkMessage` with a 4-byte length header and splits it into MTU-sized chunks;
`BLEMessageReassembler` accumulates delivered chunks and yields complete messages once enough
bytes have arrived — needed because a JSON-encoded message (particularly `.state` with an active
`CastSolution`) may exceed one BLE packet. The unreliable `.state` path deliberately never
fragments — an oversized sample is dropped outright rather than risking a multi-chunk stream
desyncing on a channel with no delivery guarantee, matching `NetworkMessage.
requiresReliableDelivery`'s existing "stale sample is worthless" reasoning. The two reliable
paths may fragment safely, relying on CoreBluetooth's own per-chunk acknowledgment (indicate's
`updateValue`/`peripheralManagerIsReady`, write-with-response's `didWriteValueFor`) and a FIFO
send queue so overlapping logical messages can't interleave.

**Concurrency.** `TransportProtocol`, `TransportClient`, and `TransportHost` are all `@MainActor`
— both CoreBluetooth managers are constructed with `queue: nil`, so delegate callbacks already
land on the main queue in practice; the isolation makes that explicit and matches the only two
callers (`RodViewModel`/`WorldViewModel`, both already `@MainActor`). CoreBluetooth's delegate
protocols are Objective-C and unisolated; the conformances use `@preconcurrency`, the standard
bridge for this exact pattern.

**Reconnection** is automatic on both sides while a session is still wanted: Rod keeps
advertising after a central unsubscribes, World restarts scanning after any
disconnect/failed-connect — matching MPC's previous behavior of leaving the browser/advertiser
running continuously once `connect()` was called, rather than requiring the caller to retry.

Full rationale, the message-flow inventory used to design the GATT layout, and the platform
entitlement changes (`Info.plist`, `ENABLE_RESOURCE_ACCESS_BLUETOOTH`) are in ADR-035.

------------------------------------------------------------------------

## World Main Menu (ADR-036)

`WorldViewModel.Screen` (`.mainMenu`/`.playing`) gates what `ContentView` shows on top of the
always-mounted RealityKit scene — the Main Menu and Result screen are `ZStack` overlays, not a
replacement view hierarchy, so returning to the menu never re-triggers
`EnvironmentSceneBuilder.build()`'s asset loading (~200 scattered instances plus the core
dock/water/terrain/rod-rig assets).

```text
.mainMenu (default)
   -> RodState.isFishing flips true (player pressed "Start Fishing" on Rod)
   -> .playing

.playing
   -> hookPhase == .result -> "Continue Fishing" (continueFishing()) -> .playing, hookPhase == .idle
   -> RodState.isFishing flips false (player pressed "End Fishing" on Rod,
      or Rod disconnects) -> returnToMenu() -> .mainMenu, hookPhase == .idle
```

**Screen transitions are Rod-driven, not World-button-driven, as of ADR-038** — see that ADR and
its own section below for the full design. `World/World/Views/MainMenuView.swift`: title,
subtitle, and a status row reflecting every `ConnectionState` case (no button); solid black
background, deliberately opaque so gameplay never visibly renders through the title screen.

Rod is never disconnected by returning to the menu — `content`'s transport lifecycle
(`.onAppear`/`.onDisappear`) is tied to `ContentView`'s own lifetime, not to `screen`, so the
connection established while the Main Menu was first shown persists across any number of
menu/play round-trips within one app session.

Closed the "Return to Menu... no Main Menu yet" gap noted in the Result Screen section above and
in `CHECKPOINT.md`'s Rod's Minimal V1 Interface entry — first by adding a World-side button here,
then (ADR-038) by removing that same button once Rod became the session's sole authority.

------------------------------------------------------------------------

## Fish Tiers and Progression (ADR-037)

`FishSpecies` (Shared) gained `tier: FishTier` (`.small`/`.medium`/`.big`/`.boss`).
`World/World/Gameplay/FishCatalog.swift` now defines one species per tier — `fish_a` (`.small`),
`fish_b` (`.medium`), `fish_c` (`.big`), `scott` (`.boss`) — each a rough, explicitly-unbalanced
scale-up of the previous tier's weight/length/resistance/value; `randomSpecies(unlockedTiers:)`
filters the pool to what's currently unlocked instead of returning any species unconditionally.

**`World/World/Gameplay/ProgressionStore.swift`** (new) persists cumulative catches per tier the
same way `FishRecordStore` persists catch records, and derives:

```text
level: Int                                     — 1, 2, or 3, from the catch counts below
unlockedTiers: Set<FishTier>                   — which FishCatalog entries randomSpecies(unlockedTiers:) may pick
progressTowardNextLevel: (caught: Int, needed: Int)?  — nil once level 3 (nothing left to unlock)

Level 1 (start):        .small catchable
-> 10 .small caught ->  Level 2: .medium also catchable
-> 10 .medium caught -> Level 3: .big AND .boss (Scott) also catchable
```

**`FishFightController`** takes a `ProgressionStore` (injectable/defaulted, same pattern as
`recordStore`). Publishes `currentLevel: Int` and `levelUpAnnouncement: String?`
(`dismissLevelUpAnnouncement()` clears it) alongside the existing `caughtCount`/
`lastCatchResult`. `resolve(outcome:)`'s `.caught` branch — the single place a successful catch
is already processed for stars/coins/records — also calls `progressionStore.recordCatch(tier:)`
and sets `levelUpAnnouncement` if the returned level is higher than `currentLevel` was.

**HUD**: the "Caught" `GroupBox` in `ContentView` gained a "Level N · x/10 to next tier" row.
New `World/World/Views/LevelUpBannerView.swift` — a dismissible, non-auto-fading toast pinned to
the top of the screen — renders whenever `levelUpAnnouncement` is set; it can appear stacked
above `ResultView` (the catch that crosses a threshold is still a normal catch too), since
neither view gates the other.

`.boss` (Scott) is deliberately its own tier rather than the top of `.big`'s weight range — a
distinct, singular, narratively-flagged encounter per the product ask, not just another random
roll from the same pool as regular big fish — and unlocks at the same Level 3 threshold as
`.big`, since three levels were specified, not four.

------------------------------------------------------------------------

## Rod Owns the Session Boundary (ADR-038)

`RodState` (Shared) gained `isFishing: Bool`, riding along in the existing ~30 Hz `.state`
stream — no new message type. `WorldViewModel.handle(_:)` compares each incoming
`state.isFishing` against the previous value: rising edge starts the session
(`screen = .playing`), falling edge ends it (`returnToMenu()`).

```text
Rod:   RodViewModel.isFishing (local)  --(RodState.isFishing, every .state)-->  World
World: handle(_:) edge-detects isFishing  ->  screen = .playing / returnToMenu()
```

`returnToMenu()` (now `private`) is no longer gated to `hookPhase == .result` — pressing "End
Fishing" on Rod works at any point during a session, not just after a catch — so it resets
whatever fight/hook state was mid-flight (hook velocity, hook entity, `fishFight.
resetForNewCast()`, `hookPhase` back to `.idle`) before switching `screen`. It's also called as a
fail-safe from `transport.onStateChange` on `.disconnected`/`.failed`, since a dropped connection
means no further `.state` messages ever arrive to flip `isFishing` — without this, `screen` would
stay stuck on `.playing` with no controller left to end it.

Both of World's own session-control buttons are gone as a direct consequence: `MainMenuView`'s
"Start Fishing" (calling the now-deleted `startGame()`) and `ResultView`'s "Return to Menu"
(added one ADR ago, in ADR-036) — keeping either would just get silently overridden back by the
next `.state` message, since Rod's `isFishing` wouldn't have actually changed. `MainMenuView` is
now purely a status display.

Rod's own `ContentView.swift`: the old three-button stack (Start/Calibrate/End, with Start and
End both always present but oppositely enabled) becomes one button whose label/action/style
swaps on `isFishing` — "Start Fishing" or "End Fishing", never both. Calibrate moved out of that
stack into a `ToolbarItem(placement: .topBarTrailing)` in the phone's top-right corner, reusing
the existing per-step `calibrationButtonTitle` text rather than duplicating it.

------------------------------------------------------------------------

## World Audio Subsystem (ADR-040)

`World/World/Audio/` holds a two-layer sound system that structurally mirrors Rod's haptics
layer (`Rod/Rod/Haptics/HapticManager.swift` + `FishingHaptics.swift`):

-   `SoundManager` — low-level AVFoundation playback, no gameplay knowledge. One preloaded
    `AVAudioPlayer` per `Sound` case (`prepareToPlay()` at init to avoid a first-play hitch), with
    `play`/`startLoop`/`stopLoop`/`stopAllLoops`/`setVolume` primitives.
-   `FishingSounds` — the event router, one `handle(_ event: FishingEvent)` switch plus loop
    lifecycle helpers (`updateReelLoop`, `handlePhaseChange`, `handleScreenChange`, `stopAll`),
    same shape as `FishingHaptics.handle(_:)`.

Sound is presentation and stays out of `Shared` and off the transport. `WorldViewModel` owns a
`let sounds: FishingSounds` and funnels every World-emitted `FishingEvent` through one point so
sound and the Rod-bound transport send can never drift apart:

```swift
private func emit(_ event: FishingEvent) {
    sounds.handle(event)
    Task { await send(.fishingEvent(event)) }
}
```

Bundled assets live under `World/World/Assets/SFX/` (`.wav`/`.mp3`) — both Xcode projects use
Xcode 16 synchronized root groups, so anything placed under `World/World/` is auto-bundled with
no `.pbxproj` resource entries needed, loaded the same way `WaterMaterial.swift` already loads
its textures: `Bundle.main.url(forResource:withExtension:)`.

Event -> sound mapping: `hookSplash` -> splash one-shot; `fishInterested` -> starts a bubble
loop; `fishBite` -> stops the bubble loop and plays a bite one-shot; `catchFish` -> stops the reel
loop and plays a catch splash; `fishEscaped`/`lineBreak` -> reuse the splash one-shot (no
dedicated asset recorded yet); tension-band events are routed through for symmetry but stay
haptic-only. `.cast` has no World-emitted `FishingEvent` (Rod generates it locally from motion),
so `launchHook(solution:)` calls `sounds.castLaunched()` directly. The reel loop is driven every
tick from `rodState.action`/`hookPhase` rather than from an event, so an empty-line retrieve
during `.hookInWater` (no fish on hook yet) still sounds, not just a fish fight. `setHookPhase(_:)`
calls `sounds.handlePhaseChange(_:)` on every transition as a belt-and-suspenders stop for stale
loops, mirroring `FishingHaptics.stopInterest()`/`stopFight()`. A looping lake ambience track
plays across both the main menu and gameplay (`FishingSounds.Config.ambiencePlaysInMenu`),
started from `start()`/screen transitions and stopped only in `WorldViewModel.stop()`.
