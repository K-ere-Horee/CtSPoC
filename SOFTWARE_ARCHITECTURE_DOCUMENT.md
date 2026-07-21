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

`CastSnapshot` is immutable and contains corrected orientation, timestamp, and
`backswingHoldDuration` (seconds): how long the backswing/charging pose was
held before release, tracked by `RodMotionInterpreter` and reset whenever a
fresh cast gesture begins. `CastResolver` computes horizontal direction,
launch angle, and normalized power — as a continuous **timing-meter
oscillation**, not a charge ramp (ADR-057):

```text
phase = backswingHoldDuration * 2π / oscillationPeriod
power = (1 - cos(phase)) / 2
```

Power starts at `0`, rises to `1` at half the period, falls back to `0` at the full period, and
repeats indefinitely for as long as the backswing is held — a classic "hit the peak" timing-minigame
curve ("meteran naik turun perlahan"), replacing ADR-054/056's monotonic ramp entirely. The flick
(`forwardMotion`, an acceleration-threshold check in `RodMotionInterpreter`) still *triggers* the
release — unchanged since ADR-032 — it just locks in whatever the oscillation reads at that instant
rather than a value that only ever grew with hold time (it never scaled the result at all, per
ADR-056). `RodMotionInterpreter` tracks `castHoldStartTimestamp`, set the instant a cast attempt is
armed (see below) and the pose first reads as a cast attempt; `holdDuration` is the elapsed time
since, transmitted live as `RodState.castHoldDuration` (not just the normalized `castPower`) so
World can show the actual timer alongside the oscillating bar. `RodMotionInterpreter`'s live
`castPower` (the charging-phase meter) applies the identical formula locally (keeping its own
`oscillationPeriod` constant in sync with `CastConfig`'s) so the on-screen meter always agrees with
what the eventual release will produce; `CastResolver`, driven by `CastConfig.oscillationPeriod`
(3.5s), remains the single authoritative calculation that becomes the transmitted
`CastSolution.power`. `CastSnapshot.angularVelocity`/`CastConfig`'s velocity bounds and the
per-axis `rotationRateX/Y/Z` plumbing that only ever fed the old flick term were removed outright
(ADR-056) rather than left dead — confirmed via `grep` that nothing else depended on any of it.

**Re-arming always wins over a stale `followThrough` freeze-frame (ADR-057 correction).** A fresh
"Start Casting" press resets `castEndsAt` to the current timestamp before the `followThrough`
early-return is checked, so a still-ticking cooldown from the *previous* cast (a purely local,
World-round-trip-independent timer) can never leak that cast's frozen `releasedCastPower` into a
new attempt — without this, re-arming shortly after a release could read as "power is already
maxed" the instant the button is pressed.

**World's `CastMeterView` is now actually shown (ADR-056).** Its call site in
`World/ContentView.swift` had been commented out; the view itself was already correct (per ADR-045's
finding), it just was never in the render tree. Now uncommented, with a `holdDuration` parameter
rendering a live "Holding X.Xs" readout alongside the existing normalized power bar.

**A cast attempt must be explicitly armed first (ADR-050).**
`RodMotionInterpreter.interpret(_:isCastingArmed:)` treats a cast-classified
pose exactly like `.idle` — no backswing tracking, no charging phase, no cast
meter — unless `isCastingArmed` is `true`. Rod's "Start Casting" button
(`RodViewModel.startCasting()`) is the only way to set it, guarded to
`isFishing && (hookPhase == .idle || hookPhase == .result)` (the `.result`
branch is ADR-061, see below); it clears automatically once a cast actually
fires, once `hookPhase` leaves `.idle`/`.result` for any reason, or on
`endFishing()`. This adds intent on top of the existing motion math above —
it does not change how power/direction are computed once a real attempt is
armed and running. `CastMeterView`'s visibility logic itself needed no
changes for this: it already follows `RodState.motionPhase` reaching a
charging-related phase, which now only happens once armed (the view's call
site being commented out, unrelated to arming, was fixed separately above).

**The meter now starts the instant arming happens, not once the pose also drifts toward
`castPose` (ADR-061).** Before this, `interpret(_:isCastingArmed:)` only ran the
charging/oscillation logic inside `case .cast:` of a switch over the raw pose classification (the
same idle/cast/reel comparison used for gesture recognition generally) — so a player who pressed
"Start Casting" while still holding the phone in its calibrated idle position saw the meter pinned
at 0 until they *also* physically moved the phone closer to `castPose`, reading as an unexplained
delay between pressing the button and the meter appearing. The armed-charging logic (hold-duration
tracking, the oscillation formula, backswing/forward-motion phase detection, release) now runs
unconditionally whenever `isCastingArmed` is `true`, before the pose-classification switch is even
reached; the switch only still matters while *not* armed (deciding idle vs. reel vs. an unarmed
cast-pose read, unchanged). The flick-detection logic itself (`accelerationZ` crossing
`profile.castAcceleration`) was always independent of pose classification, so this only removes the
classification *gate* on entering the branch — nothing about how a flick is detected or how power
is computed changed.

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

## Rod Rig Visual Fixes (ADR-051)

`World/World/Reality/RodRigController.swift` drives `rod_main.usdz`/`rod_line.usdz`'s live bone
pose each frame (both ship as rest-pose-only skeletons — see the "Asset-Integration Environment"
`CHECKPOINT.md` entry for the original rig setup). Three fixes:

- **Bend smoothing.** `applyBend(pitch:roll:)` (now `mutating`) low-pass-filters the raw
  `pitch`/`roll` it receives (`bendSmoothing = 0.25`) before computing per-joint bend angles — the
  primary whole-rig rotation (`updateRodPose()`'s `RodState.orientation`, per ADR-016) is untouched;
  this only smooths the secondary flex effect layered on top of it.
- **Placeholder reel spin.** `rod_main.usdz` has no reel geometry or joint at all (confirmed by
  extracting and reading the asset directly — its mesh data is the rod blank plus two material
  subsets, nothing else). A flattened-sphere placeholder is pinned near the `Handle` joint and spun
  via the new `applyReelSpin(reelSpeed:isReeling:deltaTime:)`, called from
  `WorldViewModel.tick(deltaTime:)` alongside `applyLineTension`. A real modeled reel remains a
  follow-up asset-repo task.
- **Line-follow fix.** `applyLineTension(_:)` previously rotated the line's sag around a fixed
  local-X axis, but the line's root inherits the rod Tip joint's full world orientation — under
  combined pitch+roll the sag axis rotated along with the tip's own roll, forking the line away from
  the rod's bend plane (a previously known, unfixed issue). Now reads `tipEntity`'s current world
  orientation and rotates the sag axis by its inverse first, keeping the sag pointed at a stable
  world-frame direction regardless of the rod's own roll.

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
(species-scaled m/s, `config.basePullSpeed(0.2625) * (1 + resistance *
config.pullSpeedResistanceMultiplier(1.8))`, zero unless hooked;
`basePullSpeed` retuned twice from its original `0.7` — halved to `0.35`
("fish pull speed rasanya terlalu kencang"), then cut a further 25% to
`0.2625` ("kurangin keduanya by 25%") — see ADR-039's own live-tested-
retune addenda) is read by `WorldViewModel.driftHookAway(deltaTime:)`
while the player rests, and — ADR-039's tug-of-war — *subtracted from
the player's reel speed inside `reelHook(deltaTime:)`* while reeling: a
net-negative speed moves the hook away even mid-reel, so a strong fish
gains line against weak reeling and can win outright via the distance
escape above.

**Reel-in speed is tension-scaled risk/reward while a fish is hooked (ADR-039 retune).** The
player's own pull-in speed used to be a single flat `WorldViewModel.reelSpeed` constant
(`3.0 -> 4.5 -> 3.375` across two earlier retune passes) applied unconditionally. Requested
directly — "balance pull nya dengan cara: ketika hijau, 1 rotasi reel misalnya narik 0.5m/s, dan
ketika ke merah reel distance nya naik jadi 1m/s gitu, jadi ada reward untuk player yang berani
stay di red zone" — `FishFightController.reelPullSpeed` now computes the per-unit pull speed from
`lineTension` itself: `config.reelPullSpeedSafe` at/below `config.reelSpeedSafeTension`
(0.7, matching `LineTensionView`'s own `safeHigh` green-zone edge — numerically aligned, not
code-shared), linearly interpolating up to `config.reelPullSpeedDanger` once tension
reaches `config.reelSpeedDangerTension` (0.85, matching `LineTensionView`'s `dangerHigh` red-zone
edge) — rewarding a player willing to hold tension near the snap threshold instead of playing it
safe. The safe/danger speeds themselves went through two more passes after launch: `0.5`/`1.0` m/s
first (unplayably slow, "the gameplay is not even playable now"), briefly `3.375`/`5.0` m/s
(restoring the old flat constant's magnitude), then explicitly retuned to **`2.0`/`4.0`** m/s
("coba base nya 2 m/s... naik jadi 4 m/s di area merah") — the values now in effect.
`reelHook(deltaTime:)` reads `fishFight.reelPullSpeed` **only while `hasFishOnHook`** —
empty-line retrieves keep the old flat `reelSpeed` constant, since there's no tension to manage in
that case. The minimum-guaranteed floor dropped from `0.39375` to a flat `0.1` for the fish-fight
path — still comfortably below the current 2.0-4.0 m/s range. The controller publishes a speed
only, it never touches RealityKit. Tension and physical hook
position move together: ignoring a hooked fish drains tension *and* lets
it swim away; over-reeling snaps the line; under-reeling loses the
tug-of-war.

**Reel-in and drift-away stay at water height until near the dock (ADR-042).**
Both `reelHook`/`driftHookAway` branch on horizontal (X/Z) distance to a target
point: beyond `hookLiftDistance` (1.0 m) the hook is pinned to `waterHeight` and
moves horizontally only, so it reads as sliding across the water's surface;
within that distance, movement switches to full 3D so the hook rises the rest
of the way up.

**Inside the lift zone, the catch/empty-retrieve resolves immediately, with no scripted climb
(ADR-061, superseding ADR-044's guaranteed-speed climb).** ADR-044 had `reelHook` advance toward
`hookLiftTargetPosition` at a fixed `dockLiftSpeed` (3.5 m/s) once inside `hookLiftDistance`,
ignoring `fishFight.fishPullSpeed`, then only resolve the catch once within a further 0.15 m of the
target — a guaranteed climb that fixed ADR-044's original "fish floating" bug (the tug-of-war
stalling right at the dock's edge) but introduced a smaller version of the same complaint: the hook
still visibly hung/drifted in the air for the beat it took to cover that last meter before landing.
Reported directly: the hook "melayang dikit" (floats a bit) near the pier instead of being caught
outright once close. `reelHook` now snaps `hookEntity.position` straight to `hookLiftTargetPosition`
and resolves the catch/empty-retrieve in the same tick the hook first crosses inside
`hookLiftDistance` — an instant, deliberate "yanked up" landing instead of a climb. The catch
cutscene's own jump animation (ADR-045/047) still sells the "lift" moment for a caught fish; an
empty line simply disappears at the same instant. `dockLiftSpeed` and the 3D-distance catch guard
are gone entirely — dead code now that there's no climb to gate behind. `driftHookAway` (used only
while the player isn't actively reeling) is unchanged and still lets an escaping fish pull the hook
back down out of the lift zone via `fishFight.fishPullSpeed`.

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
empty retrieve), `reelHook`'s lift-zone landing (ADR-061, above) calls
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

**The cutscene now shows a real animated fish instead of the placeholder
sphere (ADR-068).** `caughtFishEntity`, loaded once in `makeSceneEntity()`
via `Entity(named: "mekong_catfish_caught")` (same pattern
`EnvironmentSceneBuilder` uses for every bundled asset), replaces `hookEntity`
as what the cutscene actually shows: `beginCatchCutscene(from:)` disables
`hookEntity`, enables `caughtFishEntity`, scales it to the actual rolled catch
length (`fishFight.lastCatchResult.length` against the asset's authored 2.0 m
body length, clamped to a 0.35 minimum), and plays its one baked animation
(`availableAnimations.first` — a struggle→calm→showcase "Caught" clip). The
ADR-047 rise/freeze/settle height math was factored into a shared
`catchCutsceneHeight(elapsed:)`, used by both `updateCatchCutscene` (moves
`caughtFishEntity`, or `hookEntity` as a fallback if the asset failed to
load) and `updateCameraFollow`'s ADR-048 push-in (now computed from
`cutscene.origin` directly rather than a hidden, stale `hookEntity.position`).
Sourced from a sibling asset repo (`~/repos/new-blender-project`) that ships
ten fish species with four baked animation states each (`Cruise`/`Bite`/
`Caught`/`Preview`); only Mekong Giant Catfish was used here — that repo's own
`APP_TEAM_HANDOFF.md` documents known orientation/normals/UV export defects
on five of the other species (confirmed via on-device testing on this app's
separate, since-shelved AR fish-preview feature) and names Mekong Giant
Catfish the actual reference other species should be fixed to match. Mapping
`FishCatalog`'s four abstract tiers to distinct real species is an open
content decision, not attempted here — every catch currently shows the same
species regardless of tier. The asset is **CC-BY 4.0** (Sketchfab, "Ikan
Patin") and requires attribution; this branch has no credits screen yet to
host it (see ADR-068's own note).

**The fish orients vertically, hanging as if hooked, and its struggle plays
faster (ADR-069/072/073).** Reported directly after a live look: the fish sat
at identity rotation the whole cutscene (never set before this fix), making a
technically-playing struggle animation still read as passive/"preview-like."
Added `fishOrientation(facing:)`, a two-step construction (shortest-arc
align, then a roll correction so the dorsal fin faces up) that avoids an
arbitrary sideways/upside-down roll — still present and usable for any
non-degenerate facing direction, though not what the final pose ends up using
(see below). Its asset-specific local axes (body length along Y,
dorsal-ventral along Z) were confirmed by reading `mekong_catfish_caught
.usdz`'s own `Skeleton.bindTransforms` directly (`unzip`+`usdcat`), not
assumed from the source repo's pre-export Blender notes — this file's
`upAxis = "Z"` means it kept Blender's native convention rather than the
Y-up axis swap the sibling glTF exporter performs, so the two could
plausibly have disagreed.

Three iterations on `catchCutsceneFishOrientation` followed, each a direct
response to a live look: (1) ADR-069 fed `fishOrientation(facing:)` a
direction toward `rodRig.tipEntity`'s live position, producing an
unpredictable near-vertical pose dominated by the tip's live height above
the fish ("ikannya masih normal vertical belum horizontal seperti kondisi
ditangkep"); (2) ADR-072 replaced it with a fixed horizontal world `+X`
facing — exploiting the cutscene camera's fixed geometry
(`playerCameraPosition`/`catchCutsceneCameraStartOffset`/`EndOffset` all
share `X = 0`) to guarantee a broadside pose regardless of jump height or
camera dolly progress — but read as an ordinary swim-cycle silhouette once
seen live ("ikannya kaya berenang... harusnya kepala nya [di atas],
vertical"); (3) **ADR-073** keeps ADR-072's "fixed, not dynamic" insight but
reverses the direction back to vertical: a direct rotation-matrix
construction (not `fishOrientation(facing:)`, whose roll-correction step is
degenerate when facing is exactly world-up) points the head straight up
(world `+Y`) while aligning the fish's lateral/width axis to the camera's
`-Z` view direction, so the camera sees the fish's full broadside
length/height silhouette *while it hangs vertically* — verified by direct
`swift` REPL execution of the exact construction, not derivation alone.

Separately, `beginCatchCutscene` originally set a hardcoded `.speed = 1.4` on
the played clip's `AnimationPlaybackController` (ADR-069) — a tempo-only
change, since the asset repo's own `Source_Log.md` documented that clip's
authored motion as deliberately gentler/slower-cadence than other fish, which
a playback-rate change alone couldn't add amplitude to. Superseded by ADR-071
once the clip itself was replaced (see below).

**The freeze phase gained an in-code slow-motion envelope (ADR-070).**
`updateCatchCutscene`'s `cutscene.elapsed` — the single story clock
`catchCutsceneHeight(elapsed:)` and the ADR-048 camera dolly both already
read — now advances at `deltaTime * catchCutsceneTimeDilation(elapsed:)`
instead of raw `deltaTime`. `catchCutsceneTimeDilation(elapsed:)` is `1`
outside the freeze phase and, inside it, eases from `1` down to
`catchCutsceneSlowMotionFactor` (`0.3`) over the first 20% of the freeze
window, holds at `0.3` through the middle 60%, then eases back to `1` over
the last 20% — avoiding an abrupt jump-cut into/out of bullet-time at the
freeze's own boundaries. Because position and camera already derive
everything from `cutscene.elapsed`, slowing that one value automatically
slows both together; `caughtFishAnimationController` (kept from
`beginCatchCutscene`'s `playAnimation(_:)` call) is separately retargeted to
`catchCutsceneFishAnimationSpeed * dilation` every frame so the fish's own
struggle visibly slows and speeds back up in lockstep too, not just the
world-space motion around it. Real wall-clock time to get through the
freeze's nominal 0.9 s "story" duration is now considerably longer while
dilated (~2.3–2.4 s at current constants).

**A second dip extends the ending, and the hook/line stay attached to the
fish (ADR-074/075).** `catchCutsceneTimeDilation(elapsed:)` was generalized
from "dip only during the freeze phase" to "dip during whichever of freeze
or settle `elapsed` currently falls in," reusing the exact same
ease-in/hold/ease-out shape and constants for both — so a second bullet-time
moment now plays as the cutscene ends, not just at its peak. Separately,
`hookEntity` is no longer disabled the instant the cutscene starts — it's
repositioned every frame to `caughtFishEntity`'s position plus
`caughtFishHeadOffset` along the fish's head axis, scaled to match the
fish's current display size, so the hook stays visually parked at the
fish's mouth through the whole cutscene instead of vanishing.
`tick(deltaTime:)`'s line-tension call now uses a new
`catchCutsceneLineTension` (`0.8`) while `isShowingCatchCutscene` is true,
instead of the `0` (fully slack) `lineTension(for:)` previously returned for
the whole `.result` phase, so the line reads taut rather than disconnected
during the reveal.

**Retuned against a live screenshot (ADR-075).** ADR-074's
`catchCutsceneSettleDuration` (`1.85` s, a flat "+1.5 s") produced ~7+ s of
real time once the slow-motion dilation multiplier was actually accounted
for — confirmed too long. Solved properly: for a phase of story duration `D`
under the shared dilation shape, real time is exactly `D × C` where
`C = ∫₀¹ du/dilation(u)` is a constant (`≈2.688` at the current
factor/ease-fraction values) independent of `D` itself — computed by numeric
integration, then solved for the settle duration that makes total real time
exactly `5.0` s: `0.35 + C×(0.9 + settle) = 5.0` → `settle ≈ 0.83`. Rise and
freeze durations (and the freeze-dependent animation peak-alignment math)
are untouched — only the ending's dip got shorter. `caughtFishHeadOffset`
also changed, `0.6` -> `1.0` -> `1.15` across two live screenshots: the old
value came from the `Head` *joint's* bind-pose position, but the first
screenshot showed the hook sitting on the fish's eye/head rather than past
the snout — re-read the `.usdz`'s `extent` attribute (the mesh's actual
measured bounds, not the skeleton) and found the real geometry reaches
local Y ≈ −1.0, well past the joint; a second screenshot at `1.0` still
showed the hook slightly short, nudged to `1.15` (a small clearance past the
measured extent). `hookEntity`
is now also scaled to match `caughtFishEntity.scale` (previously fixed-size
regardless of the fish's own display scale, part of the same reported
"broken" look on smaller catches), reset to `1` in `launchHook` for the next
cast.

**A dedicated cutscene-only line was tried and removed (ADR-076/077).**
`rod_line.usdz`'s own rig (`RodRigController.applyLineTension`) only bends a
fixed-length bone chain — there's no code path that extends its reach, and
the cutscene's hook sits roughly 2.6 m further from the rod's anchor than
any mid-fight distance that rig spans, so it never reached the cutscene's
framing at all (confirmed by reading `RodRigController.swift` directly, not
guessed from the screenshot showing no line). ADR-076 added a
`cutsceneLineEntity` — a plain thin cylinder stretched and oriented by
simple vector math every frame between the hook and the live rod tip — as a
lower-risk alternative to driving the skinned `rod_line` rig beyond its
authored length. A live screenshot showed the straight, constant-radius
cylinder reading as a rigid pole rather than a flexible fishing line;
**ADR-077 removed it entirely** rather than iterate further under pressure
to "fix it now." The cutscene currently shows the hook attached at the
fish's mouth with no connecting line at all — a known, explicitly flagged
gap, not an oversight.

**The new "Caught" clip lands its peak beat inside the slow-motion dip by
construction (ADR-071).** The `Caught` clip itself was re-authored in
Blender per the ADR-070 handoff and re-copied in (same model/rig — verified
byte-identical `bindTransforms` to the previous file — only the animation
replaced; 90 frames/3.75 s, up from 72 frames/3.0 s). `catchCutsceneFishAnimationSpeed`
changed from a hardcoded `1.4` (ADR-069, tuned for the *old* clip's
deliberately gentle tempo) to a computed property:
`caughtFishAnimationPeakTime / (catchCutsceneRiseDuration +
catchCutsceneFreezeDuration / 2)` — since both `cutscene.elapsed` and the
animation controller's `.speed` are scaled by the identical per-frame
dilation value each tick, clip-time consumed per unit of *story* time
reduces to a plain constant independent of dilation, so this formula
guarantees the clip's reported peak frame (44, ≈1.83 s in) lands exactly at
the freeze phase's story-time midpoint — always the dip's deepest point,
regardless of its specific factor/ease shape. No other cutscene constant
changed.

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
fish size. Band intensities were raised (ADR-054, "haptic nya kurang
kerasa kenceng") from 0.30/0.45/0.70 to 0.50/0.70/0.95, then maxed
outright (ADR-060) to 1.0/1.0/1.0 — the largest value CoreHaptics'
`hapticIntensity` parameter accepts, alongside every other
`HapticManager` pattern (cast, splash, reel tick, bite, catch, line
break, escape, interest) also raised to 1.0. `sharpness` was left
untouched at both passes — it controls timbre (crisp vs. dull), not
felt strength, so band differentiation (low vs. medium vs. high) still
reads through rhythm interval and sharpness even with intensity now
identical across all three.

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

**Fight direction: a timed left/right juking sub-phase (ADR-053).** The instant a fish bites,
`fishFight.fightDirection` (`.left`/`.right`) starts a random 5-10s window (config-driven), flipping
to the opposite side every random 0.6-1.8s — layered *on top of* the tension formula above, not a
separate failure mode. `updateFight` takes `RodState.roll` and applies a tension delta each tick:

```text
correctly countering (.left needs rodRoll >= threshold, .right needs rodRoll <= -threshold)
  -> tension -= fightDirectionCounterRelief per second
not countering
  -> tension += fightDirectionPenalty per second
```

A fish pulling `.left` requires a positive rod roll (leaning the rod right) to counter, matching
real-fishing "rod-side pressure" — keeping the rod angled opposite a fish's sideways run. Purely
visual, separate concern: `WorldViewModel.updateFightDirectionDrift(deltaTime:)` nudges the hook's
world-X position toward the current direction (clamped near the rod's own X) so the fish visibly
darts side to side; this never feeds back into the tension check above, which reads `RodState.roll`
directly. Surfaced on `LineTensionView` (World HUD, not Rod) as a "Fish pulling ←/→" / "Lean rod
→/←" row — Rod has no way to convey a left/right cue haptically, and World already owns gameplay
HUD. All seven new numbers live in `FishFightConfig` alongside the rest of the fight tuning.

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

**Tier 3/4 eased (ADR-054).** `FishCatalog.swift`'s `resistance` ceilings for `fish_b`, `fish_c`
(tier 3, big), and `scott` (tier 4, boss) were tuned down to `0.10` each (an initial, more modest
`0.75 -> 0.60`/`0.95 -> 0.75` pass for `fish_c`/`scott` was superseded by this further cut).
`fish_a` alone keeps its original `0.35`.

**Cast distance gates fish size in three discrete zones, matching the cast meter's own
green/yellow/red bands (ADR-063, superseding ADR-031's continuous ceiling).**
`WorldViewModel` measures the real horizontal distance a cast traveled —
`simd_distance` between the hook's launch position (captured in
`launchHook(solution:)`) and its splash position (in
`simulateFlyingHook(deltaTime:)`) — and passes it to
`FishFightController.resetForNewCast(castDistance:)`. This is distinct
from `CastSolution.distance`, Rod's cast-meter estimate shown during
charging, which is not wired to launch physics. `FishFightController`
publishes it as `lastCastDistance` (shown in `ContentView`'s Controller
State grid) and derives a `castZone` from it, exactly mirroring
`CastMeterView`'s three equal-width power-bar thirds:

```text
ratio = clamp01(castDistance / maxExpectedCastDistance)   // maxExpectedCastDistance = 20.0
castZone = ratio < 1/3 ? green : ratio < 2/3 ? yellow : red
```

ADR-031 originally capped the bite roll with a single continuous ceiling (`0.3 + 0.7 * ratio`) that
only bounded the *top* of the roll — a short cast could still occasionally land a small-to-modest
fish anywhere under that ceiling, but nothing stopped a longer cast from also rolling low, so
"cast farther -> bigger fish" was a soft tendency, not a guarantee. Requested directly: "jika user
hanya bermain di area hijau dari cast, maka ikan bintang 1-2 saja yang bisa ditangkap ... jika
kuning, maka bintang 3-4, jika area merah, maka bintang 4-5" (if the player only plays in the
green zone, only 1-2 star fish should be catchable; yellow -> 3-4 stars; red -> 4-5, the biggest).
`sizeRollWindow` now gives each zone a hard **floor and ceiling**, derived by inverting
`stars(forWeight:in:)`'s own `1 + round(4 * ratio)` formula at each star boundary so the window
exactly covers the advertised tier:

```text
green:  ratio in [0.000, 0.375)  -> stars 1-2
yellow: ratio in [0.375, 0.875)  -> stars 3-4
red:    ratio in [0.625, 1.000]  -> stars 4-5
rolledWeight/Length = random(min + span * floor, min + span * ceiling)
```

(Yellow and red both cover ratio `[0.625, 0.875)`, i.e. both can roll a 4-star fish — intentional,
matching the user's own overlapping wording.) `biasedRoll(in:floorRatio:ceilingRatio:)` replaces
the old ceiling-only `biasedRoll(in:ceilingRatio:)`. Since `sizeRatio`/`resistance` above already
derive from the rolled weight/length, a far cast landing a big fish is still automatically a
tougher fight too — that part of ADR-031's rationale is unchanged.

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
`1.5...4.0s` timer. `isFishInterested: Bool` is `@Published`; its World visual
consumer is the floating bobber's dip animation (see "Floating Bobber" below,
ADR-052) — fish still have no visual representation of their own, but the
hook now visibly reacts to their presence. `FishingEvent.fishInterested` fires once when interest
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
`hookPhase == .result`) is the only way back to `.idle`. Originally called
by `World/World/Views/ResultView.swift`'s own "Continue Fishing" button;
ADR-061 (see below) later removed that button in favor of Rod's "Start
Casting" driving the same dismissal, so `ResultView` no longer owns any
control of its own. "Return to Menu" was initially left unimplemented here
since no Main Menu existed yet to return to — see ADR-036, where it was
added alongside the Main Menu itself. Escape and line-break intentionally do not
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

**Closed by ADR-064** (see its own section below): `RodState` now transmits `calibrationStep`
live, World renders its own reactive calibration guidance from it, and a new onboarding flow
covers the game-explanation/objective/levels half of the "Tutorial" gap. Rod's own
`calibrationInstruction` text was deliberately left in place, not removed — see ADR-064's own
rationale for why both screens keep their own copy.

## Floating Bobber (ADR-052)

`WorldViewModel.updateBobberFloat(deltaTime:)`, called from `tick()`'s `.hookInWater` case whenever
the player isn't reeling, gives the hook two layered vertical motions on top of `waterHeight`:

```text
idleBob     = sin(bobberBobPhase * idleBobFrequency * 2π) * idleBobAmplitude        (0.02 m, 0.5 Hz)
interestDip = fishFight.isFishInterested
                ? -abs(sin(bobberBobPhase * interestDipFrequency * 2π)) * interestDipAmplitude
                : 0                                                                  (0.06 m, 2.0 Hz)
```

`idleBob` is always present — small, slow, ambient buoyancy realism so the bobber never reads as
frozen in place. `interestDip` layers on top only while `fishFight.isFishInterested` (ADR-029) is
true, and is downward-only (`-abs(sin(...))`) and sharper/faster than the idle bob — a fish
visibly nibbling and tugging the float toward the surface before the actual bite fires, giving the
transition into `.fishOnHook` a visual lead-up instead of no warning at all. Deliberately does not
run while reeling (`reelHook`) or while a fish is hooked (`driftHookAway`/the fight mechanics) —
those already own `hookEntity.position.y` for their own reasons and would otherwise fight this
function for control of it on the same tick. `bobberBobPhase` resets on every fresh splash.

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

**Manual retry (ADR-061).** Reported directly: the Rod<->World BLE link occasionally wedges into a
state the automatic reconnection above never recovers from, previously only fixable by
force-quitting and relaunching World. `WorldViewModel.retryConnection()` runs the same
disconnect-then-connect sequence a full relaunch would (`transport.disconnect()` tears down
whatever connection/scan state exists, then `transport.connect()` starts fresh), without losing
`screen`/`fishFight`/progression state along with it. Exposed as a "Retry Connection" button on
`MainMenuView`, shown only while `!isRodReady` (retrying a healthy link would just interrupt it).
Safe to call from any `ConnectionState`, including mid-scan or mid-connect — `TransportHost`'s own
`disconnect()`/`connect()` are already idempotent-safe to call in any state.

Full rationale, the message-flow inventory used to design the GATT layout, and the platform
entitlement changes (`Info.plist`, `ENABLE_RESOURCE_ACCESS_BLUETOOTH`) are in ADR-035.

**Device pairing allowlist (ADR-049).** The scan-and-connect-to-first-match behavior above only
holds true until a pairing exists. `PairedDeviceStore` (World) and `PairedCentralStore` (Rod) each
persist the other side's CoreBluetooth identifier (`CBPeripheral.identifier`/`CBCentral.identifier`)
via `UserDefaults` after the first full successful connection, and both `didDiscover`/
`didSubscribeTo` ignore any device that isn't the saved one from then on — `retrievePeripherals
(withIdentifiers:)` lets World reconnect to a known Rod without a fresh scan when possible. Rod's
side also restricts `updateValue(_:for:onSubscribedCentrals:)`'s target list to the paired central
specifically (not `nil`, which would send to every subscriber regardless of pairing), since an
unpaired Mac subscribing is otherwise still a real BLE subscriber that would receive live data.
`TransportHost.forgetPairedDevice()`/`TransportClient.forgetPairedDevice()` clear the saved
identifier to re-enter first-run pairing. Surfaced in World's Main Menu ("Paired with `<name>`" +
"Forget Device") and, as of ADR-062, a standalone row on Rod's primary screen ("Paired with
`<short ID>`" + "Forget Paired Mac") — Rod's original button of the same name lived in its
Developer Details `DisclosureGroup`, which is commented out (predates recent sessions, left alone
as likely in-progress work elsewhere), so `RodViewModel.forgetPairedDevice()` had no reachable
caller until ADR-062 added this separate, minimal affordance instead of touching that block.

**A mismatched pairing fails silently, not loudly, on Rod's side specifically (ADR-062).**
CoreBluetooth gives a GATT peripheral no way to *reject* a subscription — `didSubscribeTo` firing
with a central whose identifier doesn't match the saved `pairedCentralStore.identifier` still lets
the subscription succeed at the protocol level (so the far side reads `.ready`/`.streaming`
correctly), Rod just never sets `subscribedCentral` for it, so `sendTargets` (`subscribedCentral.map
{ [$0] }`) stays empty and nothing — not even the first `.state` message — is ever actually sent.
World's `TransportHost.didDiscover` avoids the equivalent trap by filtering *before* connecting to
a mismatched peripheral at all, an option only available on the central side. A stale saved pairing
on Rod (e.g. World's own "Forget Device," which only ever clears World's side, used as a
troubleshooting step) was previously unrecoverable from Rod's UI at all — the "Forget Paired Mac"
row above is the fix. Separately, both `TransportHost`/`TransportClient`'s `NetworkMessage` decode
paths were logging nothing on failure (`try? ... else { continue }`); both now log the error under
`#if DEBUG` so a genuine schema mismatch (as opposed to this pairing-mismatch trap) is
distinguishable from it during future debugging.

------------------------------------------------------------------------

## World Main Menu (ADR-036)

`WorldViewModel.Screen` (`.mainMenu`/`.playing`) gates what `ContentView` shows on top of the
always-mounted RealityKit scene — the Main Menu and Result screen are `ZStack` overlays, not a
replacement view hierarchy, so returning to the menu never re-triggers
`EnvironmentSceneBuilder.build()`'s asset loading (~200 scattered instances plus the core
dock/water/terrain/rod-rig assets).

```text
.onboarding (default on a fresh install, ADR-064)
   -> completeOnboarding() (OnboardingView's final page, or "Skip Intro")
   -> .mainMenu (persists hasSeenOnboarding, so this default only ever applies once)

.mainMenu (default on every later launch)
   -> showOnboarding() ("How to Play" button, ADR-064) -> .onboarding (round-trips back here)
   -> RodState.isFishing flips true (player pressed "Start Fishing" on Rod)
   -> .playing

.playing
   -> hookPhase == .result -> RodState.isCastingArmed true (player pressed "Start Casting" on
      Rod, ADR-061 — continueFishing()) -> .playing, hookPhase == .idle
   -> RodState.isFishing flips false (player pressed "End Fishing" on Rod,
      or Rod disconnects) -> returnToMenu() -> .mainMenu, hookPhase == .idle
```

**Screen transitions are Rod-driven, not World-button-driven, as of ADR-038** — see that ADR and
its own section below for the full design. `World/World/Views/MainMenuView.swift`: title,
subtitle, a status row reflecting every `ConnectionState` case, and (ADR-061) a "Retry Connection"
button shown only while not yet connected — the one button this screen owns that isn't gameplay
session control (alongside "Forget Device"/"Reset Progress", both likewise unrelated to the
ADR-038 session boundary); solid black background, deliberately opaque so gameplay never visibly
renders through the title screen.

Rod is never disconnected by returning to the menu — `content`'s transport lifecycle
(`.onAppear`/`.onDisappear`) is tied to `ContentView`'s own lifetime, not to `screen`, so the
connection established while the Main Menu was first shown persists across any number of
menu/play round-trips within one app session.

Closed the "Return to Menu... no Main Menu yet" gap noted in the Result Screen section above and
in `CHECKPOINT.md`'s Rod's Minimal V1 Interface entry — first by adding a World-side button here,
then (ADR-038) by removing that same button once Rod became the session's sole authority.

------------------------------------------------------------------------

## Onboarding & Live Calibration Guidance (ADR-064)

Closes the two still-open halves of the "World Main Menu + Tutorial + Calibration instructions"
gap flagged repeatedly since ADR-029 (Main Menu itself was closed by ADR-036) — the product doc's
own "World owns... Tutorial, Calibration Instructions" statement had never actually been true
until this.

**`CalibrationStep` moves to `Shared`.** Previously a Rod-local `enum MotionCalibrationStep`
(`Rod/Rod/ViewModel/RodViewModel.swift`) with no visibility outside Rod. Now `Shared/Sources/
Shared/Models/Rod/CalibrationStep.swift`, `Codable`/`Sendable`/`Equatable`, same four cases
(`.idle`/`.cast`/`.reel`/`.complete`). `RodState` gained a `calibrationStep: CalibrationStep`
field (short wire key `"cal"`, ADR-063's compact-`CodingKeys` convention), populated at all three
`RodState` construction sites in `RodViewModel` — transmitted continuously like every other field,
no new message type.

**Calibration is no longer gated to "before the first Start Fishing."** Requested directly: change
the rule from "World must be at the Main Menu" (in practice: `!isFishing`, since `screen ==
.mainMenu` and `isFishing == false` are the same condition per ADR-038) to "`HookPhase == .idle`."
Two call sites changed to match:
- Rod's Calibrate toolbar button (`Rod/Rod/ContentView.swift`): `.disabled(!hasMotionSample ||
  isFishing)` -> `.disabled(!hasMotionSample || hookPhase != .idle)`.
- `RodViewModel.calibrateMotion()` itself gained the matching `hookPhase == .idle` guard (defense
  in depth, matching `startCasting()`'s own existing button-plus-function-guard pattern) — this is
  what actually makes recalibration reachable *mid-session*, not just relaxes a UI-only check.

No changes were needed to stop a cast from firing mid-recalibration: re-entering the sequence
(`calibrateMotion()`'s `case .complete:` branch) sets `motionInterpreter.profile.isComplete =
false` immediately, which already makes `RodMotionInterpreter.interpret(_:isCastingArmed:)` report
`.invalid` regardless of `isCastingArmed` until the sequence completes again. Rod's own "Start
Casting" button did gain one new guard, though — `calibrationStep != .complete` added to its
`.disabled(...)` — purely to keep the button's own label honest (it would otherwise still say
"Start Casting" for an attempt that silently couldn't do anything), a UI nicety exposed by this
change rather than a correctness requirement.

**`CalibrationGuidanceView`** (`World/World/Views/CalibrationGuidanceView.swift`) is a small,
reusable, step-reactive component: title/instruction text per `CalibrationStep`, plus (except at
`.complete`) an explicit "Press \u{201C}<label>\u{201D} on your Rod" callout whose label mirrors
`Rod/Rod/ContentView.swift`'s own `calibrationButtonTitle` switch — the two are written to stay in
lockstep, not derived from a shared source, since one lives in `Shared`-adjacent Rod code and the
other in World's own view layer. Rendered in two places, both driven by the same live
`rodState.calibrationStep`:
- Inline in `MainMenuView`, replacing the "Press \u{201C}Start Fishing\u{201D}..." status row
  whenever `isRodReady && calibrationStep != .complete` — covers both the very first calibration
  and any later recalibration initiated from the Main Menu.
- As a scrim + centered card overlay in `ContentView` (matching `ResultView`'s own treatment)
  whenever `screen == .playing && hookPhase == .idle && calibrationStep != .complete` — covers
  recalibration initiated mid-session, which was unreachable before this change.

Rod's own existing `calibrationInstruction`/`calibrationButtonTitle` text was deliberately left in
place, not removed, despite the product doc's "Rod must not display... tutorial content" framing:
the player is physically holding Rod while performing each calibration gesture, and World (the Mac
screen) may not even be in their eyeline at that moment — Rod's short button-label text is what's
literally in their hands, World's richer copy is the exposition layer. Both screens read the same
`calibrationStep`, so they can never show contradictory instructions.

**`OnboardingView`** (`World/World/Views/OnboardingView.swift`) is a new `Screen.onboarding` case,
shown automatically before `.mainMenu` on a fresh install (`WorldViewModel.init` reads a persisted
`world.hasSeenOnboarding` `UserDefaults` flag) and revisitable afterward via a "How to Play" button
on `MainMenuView` (`showOnboarding()`, only reachable from `.mainMenu` so it can't interrupt an
active session). Three static pages, manually paged (`@State private var pageIndex`, not
`TabView(.page)` — page-style tab views are an iOS idiom, this is a macOS app) with Back/Next, a
dot indicator, and a top-corner "Skip Intro":
1. **Welcome** — what the two-device split is (Rod as controller, World as the game).
2. **Your Goal** — catch fish, progress tiers, ultimately catch Scott (the game's namesake).
3. **Levels & Fish Tiers** — the actual `ProgressionStore` thresholds (3 small -> unlock medium, 5
   medium -> unlock big, 10 big -> unlock Scott, 1 Scott catch completes it) — written from
   `ProgressionStore.swift`'s real code, not from `ProgressionStore`'s own doc comment or ADR-037's
   prose, both of which understate the thresholds (they describe an older 10/10, three-level
   version; the shipped code has always been 3/5/10/1 across four levels).

Deliberately does not embed calibration instructions itself — the last page's "Let's Calibrate"
button calls `completeOnboarding()`, returning to `.mainMenu`, where `MainMenuView`'s own
`calibrationStep`-driven guidance (above) takes over automatically, since a first-time player's
`calibrationStep` is `.idle` at that point. Keeping these two concerns separate means the
calibration guidance component only needs to be built and tested once, not duplicated inside the
onboarding pager and mid-session recalibration.

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

**Reset Progress (ADR-055).** `ProgressionStore.reset()` clears every tier's stored catch count
back to zero, dropping `level` to 1. `FishFightController.resetProgression()` calls it and also
resyncs its own published `currentLevel`/clears any in-flight `levelUpAnnouncement`. Surfaced as a
"Reset Progress" button on `MainMenuView`, alongside "Forget Device" — a debug/utility action
unrelated to the ADR-038 session boundary, so it lives on the Main Menu rather than in the active
gameplay HUD.

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
