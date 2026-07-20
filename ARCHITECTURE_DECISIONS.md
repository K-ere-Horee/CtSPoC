# ARCHITECTURE_DECISIONS.md

# CtS PoC - Architecture Decision Record (ADR)

Version: 1.0

This document records architectural decisions that are considered stable
for the Catch the Scott Spatial Controller PoC. Future changes should
preserve these decisions unless there is a compelling technical reason
to revise them.

------------------------------------------------------------------------

# ADR-048 --- Catch Cutscene Gains Letterboxing, a Camera Push-In, and a Title Flourish

## Decision

Three presentation-only additions, all scoped to the existing catch cutscene (ADR-045/046/047), none
touching `Shared` or `Rod`:

1. **Camera push-in.** `updateCameraFollow()`'s cutscene branch (ADR-046) no longer holds a single
   static offset from `hookEntity`. It now eases from a new `catchCutsceneCameraStartOffset`
   (`[0, 1.2, 2.4]`) to the existing tight `catchCutsceneCameraEndOffset` (`[0, 0.9, 1.6]`, formerly
   just `catchCutsceneCameraOffset`) over the cutscene's full run — a `smoothstep`
   (`t*t*(3-2*t)`) of `catchCutscene.elapsed / catchCutsceneTotalDuration`, a new computed property
   summing the three ADR-047 phase durations so the camera and hook motion can't disagree on when the
   cutscene ends.
2. **Letterbox bars and a radial glow.** `CatchCutsceneView` gained top/bottom black bars that slide
   in on appear (0 to 64pt over 0.25s) and a soft yellow radial glow behind the title, plus a
   background vignette (`RadialGradient`, clear center to `black.opacity(0.5)` at the edges) — all
   purely `SwiftUI`, no RealityKit changes.
3. **Title flourish.** The "CATCH!" title's entrance changed from a simple `spring(response: 0.4,
   dampingFraction: 0.55)` (critically-damped-ish, no overshoot) to `spring(response: 0.45,
   dampingFraction: 0.45)` — low enough damping to visibly overshoot past full scale before settling,
   read as a punchier "pop." Font size grew 64 -> 72.
4. **HUD hides during the cutscene.** `ContentView`'s stat block (`LineTensionView`, the
   caught-count/level `GroupBox`, `CastMeterView`'s commented slot, the error `Text`) is now wrapped
   in a `Group` with `.opacity(viewModel.isShowingCatchCutscene ? 0 : 1)` and a matching
   `.animation(...)`. The `RealityView` and its fps/connection-state overlay are unaffected.

## Rationale

Requested directly, immediately after ADR-047's freeze landed: "dan bikin lebih 'dramatis'" (and make
it more "dramatic"). None of ADR-045 through ADR-047 individually were wrong, but stacked together
they still amounted to a static camera holding on a placeholder sphere with a single title label
fading in over an unchanged gameplay HUD — correct timing and framing, but visually flat, which reads
as the opposite of "dramatic" regardless of how good the underlying rise/freeze/settle timing is.

Each addition targets a specific flatness the others don't fix: a locked-off camera shot (even a
well-framed one, ADR-046) doesn't read as "cinematic" the way a moving shot does, hence the push-in;
a floating title over an otherwise-unchanged HUD doesn't isolate the moment, hence the HUD fade and
the letterboxing (an immediately-recognizable "cutscene mode" signal borrowed from film/games
generally); and a title that just fades in at fixed scale reads as flat compared to one with a bit of
punch, hence the overshoot spring and added glow. All four are presentation-only and layer on top of
the existing trigger/phase/camera-branch structure from ADR-045/046/047 without changing any of it —
`beginCatchCutscene(from:)`, `updateCatchCutscene(deltaTime:)`'s phase math, and the `reelHook` trigger
are all untouched.

An actual "catch" sound cue was considered but turned out to already exist: `reelHook`'s
`emit(.catchFish)` (present since before ADR-045, unchanged by any of this cutscene work) already
plays `catch_splash.wav` via `FishingSounds.handle(.catchFish)` at the exact moment the cutscene
begins, so no audio changes were needed here.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
only (see the matching `CHECKPOINT.md` entry). The push-in offsets, letterbox bar height, spring
parameters, and vignette/glow opacities are all hand-picked, not tuned against how they actually read
on-device — first-pass placeholders same as the rest of this cutscene work, expected to change again
once real fish/camera assets are integrated.

------------------------------------------------------------------------

# ADR-047 --- Catch Cutscene Holds the Fish at the Jump's Peak Instead of a Single Continuous Arc

## Decision

`updateCatchCutscene(deltaTime:)`'s single `sin`-eased up-and-down arc (ADR-045, one continuous
motion across `catchCutsceneDuration`) is replaced with three explicit phases:

1. **Rise** (`catchCutsceneRiseDuration`, 0.35 s) — ease from the origin up to
   `catchCutsceneJumpHeight` (`sin(t * .pi / 2)`, `t` = elapsed/rise duration).
2. **Freeze** (`catchCutsceneFreezeDuration`, 0.9 s) — `hookEntity` holds exactly at
   `catchCutsceneJumpHeight`, motionless.
3. **Settle** (`catchCutsceneSettleDuration`, 0.35 s) — ease back down to the origin
   (`cos(t * .pi / 2)`, `t` = elapsed-since-freeze-end/settle duration).

Both eases are continuous at the phase boundaries (rise ends at exactly `catchCutsceneJumpHeight`,
matching the freeze's held value; settle starts at exactly `catchCutsceneJumpHeight`, matching where
freeze left off), so there is no positional snap between phases. The old single `catchCutsceneDuration`
constant is removed; total cutscene play time is now the sum of the three phase durations (1.6 s, up
from the old 1.3 s). `beginCatchCutscene(from:)`, the catch trigger in `reelHook`, `ContentView`'s
overlay wiring, and ADR-046's camera-cut branch are all unchanged — only `updateCatchCutscene`'s
internal motion curve and its three new constants changed.

## Rationale

Requested directly, immediately after ADR-046's camera cut landed: "ikan dan bomber nya harus
'freeze' di cut scene agar kesan cut scene nya tidak terlalu singkat" (the fish and bobber need to
freeze during the cutscene so it doesn't feel too brief). A single continuous `sin(t * .pi)` arc
spends almost all of its time in motion and only touches its peak height for a single instant — even
at the full 1.3 s duration, the hook is only ever "at the top" for one frame, so the moment reads as
a quick blip passing through rather than a deliberate pause on the catch. An explicit held phase,
with the hook motionless at the peak for nearly a second, is what actually reads as "the cutscene
lingers on the catch," which continuous easing alone could not produce no matter how long
`catchCutsceneDuration` was set to.

Split into three phases rather than, e.g., biasing a single easing curve to spend more time near its
peak (a harder-to-read, less explicit approach) — three named, independently tunable durations make
the "how long does it hang in the air" question a single obvious constant
(`catchCutsceneFreezeDuration`) to adjust once this is played live, consistent with this pass's own
placeholder-pending-live-confirmation status.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
only (see the matching `CHECKPOINT.md` entry). All three phase durations and the total 1.6 s runtime
are hand-picked, not tuned against how the hold actually reads in a played session.

------------------------------------------------------------------------

# ADR-046 --- Catch Cutscene Cuts the Camera to the Hook, Reusing the Existing Follow-Cam Path

## Decision

`updateCameraFollow()` gained a new first branch: whenever `isShowingCatchCutscene` (ADR-045) is
true, the camera looks at `hookEntity` from `hookEntity.position + catchCutsceneCameraOffset`
(`[0, 0.9, 1.6]`) and returns immediately, before the existing `hookPhase`-based `followsHook` check
runs. `catchCutsceneCameraOffset` is deliberately closer and lower than the mid-fight trailing
`followOffset` (`[0, 1.5, 3.0]`, ADR-039) — a tighter, more deliberate shot rather than reusing the
same trailing framing the fight itself already uses. Once the cutscene ends (`isShowingCatchCutscene`
flips back to `false`, still inside `.result` while `ResultView` waits for "Continue Fishing"), the
function falls through to its existing behavior — `.result` was never in `followsHook`'s phase list,
so the camera resets to the player pose exactly as it did before this change.

## Rationale

Requested directly, immediately after the ADR-045 cutscene landed: "butuh cameranya langsung ke
bomber dan ikan yang ketangkep, biar beneran kaya cut scene" (the camera needs to cut directly to the
bobber and the caught fish, so it actually feels like a cutscene). Before this change,
`updateCameraFollow()`'s `followsHook` list was `.flying`/`.fishOnHook`/`.reeling` only — `.result`
was explicitly excluded (see its own prior doc comment, "Snaps back to the player pose for every
other phase — including `.result`"), so the ADR-045 cutscene played entirely off-camera from the
player's fixed POV, at `hookLiftTargetPosition` which is a further, more head-on angle than a
deliberate "hero shot." The jump was technically running but not actually visible as a cut.

Reused `updateCameraFollow()`'s existing look-at/offset mechanism rather than building a second
camera system — the function already exists precisely to point the camera at `hookEntity` from a
fixed relative offset, which is exactly what a "cut to the catch" needs; the only meaningful design
question was the offset itself, since a cutscene shot should read as distinct from the ongoing-fight
trailing shot, not identical to it. Gated on `isShowingCatchCutscene` rather than `hookPhase ==
.result`, since `.result` also covers the post-cutscene stat-card wait, where the camera should
already be back home per the pre-existing behavior — only the cutscene's own duration should pull the
camera in.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
only (see the matching `CHECKPOINT.md` entry). `catchCutsceneCameraOffset` is a hand-picked value
(closer than the existing mid-fight offset), not confirmed against how the shot actually frames
`hookEntity`'s jump arc (ADR-045) in a live session.

------------------------------------------------------------------------

# ADR-045 --- Catch Resolution Plays a Cutscene Before the Result Screen, as a World Presentation State (Not a New HookPhase)

## Decision

`reelHook(deltaTime:)`'s catch guard (ADR-044's `distance3D > 0.15` check) no longer disables
`hookEntity` and shows `ResultView` in the same tick a catch resolves. On a real catch it now calls
`fishFight.resolveCatch()` and `beginCatchCutscene(from:)` instead, then still sets `HookPhase` to
`.result` immediately (unchanged) — casting/reeling stay locked for the whole cutscene exactly as
before, since `.result` already had `allowsCasting == false` and `allowsReeling == false`. Empty
retrieves (no fish on hook) are untouched: `hookEntity.isEnabled = false` and `HookPhase.idle` fire
immediately, no cutscene.

The cutscene itself is a new `@Published private(set) var isShowingCatchCutscene: Bool` on
`WorldViewModel`, driven from a private `CatchCutscene { origin, elapsed }` struct ticked inside
`tick(deltaTime:)`'s existing `.result` case (previously `break`). `updateCatchCutscene(deltaTime:)`
arcs `hookEntity` upward from where it landed (`sin` easing, peak `catchCutsceneJumpHeight`, 0.6 m)
over `catchCutsceneDuration` (1.3 s), then disables it and flips `isShowingCatchCutscene` back to
`false`. `ContentView` gates a new `CatchCutsceneView` (a non-dismissable "CATCH!" title overlay) on
`isShowingCatchCutscene`, and `ResultView`'s existing condition gained `!isShowingCatchCutscene` so
the two never show at once.

`HookPhase` itself (`Shared/Sources/Shared/Models/Gameplay/HookPhase.swift`) was **not** changed —
no new case was added. `returnToMenu()` gained `catchCutscene = nil` /
`isShowingCatchCutscene = false` alongside its existing hook/fight resets, so ending a session
mid-cutscene (Rod's "End Fishing" at any point, per ADR-038) can't leave the flag stuck `true` for a
future session.

## Rationale

Requested directly, drawing an explicit comparison to casting's own already-distinct moment (Hook
Flying/Splash): "kita harus bikin 'cut scene' seperti game-game pun ... ketika bomber nya sudah
mendekati dock, dan user melakukan final reel input, akan dimunculkan 'scene' ikan dan bomber dimana
mereka melompat ke atas dan akan muncul title 'CATCH'" (build a cutscene, like other games have —
when the bobber/fish nears the dock and the player's final reel input lands it, show a scene where
the fish and bobber jump up and a "CATCH" title appears) — "nantinya, 'scene' ini akan disambungkan
dengan blender animasi asset" (this scene will later be connected to a Blender animation asset).

A new `HookPhase` case was considered and rejected: `HookPhase` is a `Shared` contract consumed by
both `Rod` (haptics, `allowsCasting`/`allowsReeling`) and `World` (rendering/HUD), per this project's
own Rod/Shared/World dependency rule (`Rod -> Shared <- World`, never Rod <-> World directly) and its
explicit statement that "Rod owns no gameplay presentation." The cutscene is pure presentation with
no distinct input-locking or haptic behavior beyond what `.result` already provides — reusing
`.result` and adding a World-only `Bool` avoids touching `Shared` or `Rod` at all for a change that is,
by its own nature, entirely a `World` rendering/HUD concern.

`hookEntity`'s jump is explicitly a placeholder — still the same `ModelEntity` sphere referenced
throughout ADR-042 through ADR-044 (there is no separate fish mesh anywhere in this codebase; see
those ADRs and `FishFightController`'s own doc comment that it "has no knowledge of transport, hook
entities, or RealityKit"). The goal of this pass is the cutscene's *timing, trigger, and state
machine* — a scripted `sin`-eased vertical arc is enough to prove and review that shape now,
independent of the later Blender asset work the request itself flags as still pending. When a real
fish mesh/animation lands, `updateCatchCutscene(deltaTime:)` is the single, well-defined place to
replace the placeholder arc with a driven animation, and `beginCatchCutscene(from:)`/the
`distance3D > 0.15` guard in `reelHook` remain the single, well-defined trigger moment — deliberately
not spread across multiple call sites.

`catchCutsceneDuration` (1.3 s) and `catchCutsceneJumpHeight` (0.6 m) are hand-picked, matching this
project's own established pattern of flagging unverified constants explicitly (see ADR-043/044)
rather than presenting them as tuned.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
(macOS) only, since this change touches no `Shared` or `Rod` files (see the matching `CHECKPOINT.md`
entry). Not yet played; the jump arc, cutscene duration, and title styling are all first-pass
placeholders expected to change once real fish assets/animation are integrated.

------------------------------------------------------------------------

# ADR-044 --- Dock-Approach Lift Uses a Guaranteed Fixed Speed, Not Tug-of-War

## Decision

Inside `hookLiftDistance` (1.0 m) of `hookLiftTargetPosition`, `reelHook(deltaTime:)` no longer
moves at `rodState.reelSpeed * reelSpeed` net `fishFight.fishPullSpeed` (ADR-039's tug-of-war). It
now always advances toward `hookLiftTargetPosition` at a new fixed constant,
`dockLiftSpeed = 3.5` m/s — faster than the player's own max reel speed (`reelSpeed`, `3.0`) — with
no subtraction for the fish's pull. Outside that zone (the open-water reel-in), the tug-of-war stays
exactly as ADR-039 left it.

`reelHook`'s catch/empty-retrieve resolution also changed from a horizontal-only distance check
(`> 0.12` m) to a full 3D distance check against `hookLiftTargetPosition` (`> 0.15` m), so resolution
now waits for the guaranteed climb above to actually finish rather than firing horizontally while the
hook may still be partway through its vertical rise.

`driftHookAway(deltaTime:)` (ADR-042), used when a hooked fish pulls line out while the player isn't
actively reeling, is unchanged — it still uses `fishFight.fishPullSpeed` in both zones, since a fish
escaping toward open water should still be able to pull the hook back down out of the lift zone.

## Rationale

Reported directly during playtesting: "ketika bomber nya sudah mulai mengenai dock nya, bomber
kuning nya masih 'melayang' ... harusnya ketika sudah menyentuh dock, harusnya ikan mulai makin
bergerak cepat pun atau langsung naik ke dock ketimbang melayang" (once the hook/fish starts reaching
the dock, it still visibly "floats" instead of speeding up or climbing straight onto the dock).

Tracing `reelHook`'s math: the tug-of-war net speed (`playerSpeed - fishFight.fishPullSpeed`) can be
small or negative even while the player is actively reeling — a documented, intentional design
(ADR-039) for the open-water fight, where a strong fish should be able to contest the player. Left
unchanged inside the lift zone, though, the same math let the hook stall in place or even sink back
toward the water right at the dock's edge, which is exactly the reported "floating" feel — a fish
this close to being landed visually has no business still winning a tug-of-war.

The catch/empty-retrieve resolution threshold was originally horizontal-only specifically so
resolution wouldn't have to wait for the hook to climb the full ~2 m up to the rod's hand height
(ADR-043's own rationale). That tradeoff no longer applies now that the climb is fast and guaranteed
rather than tug-of-war-gated — switching the check to full 3D distance means the hook visibly
finishes arriving before it disappears, instead of vanishing mid-climb, which is the second half of
the reported issue (the hook/fish should be seen reaching the dock, not just getting close to it
horizontally and cutting away).

**Forward-looking note for fish-asset integration:** `hookEntity` is still a placeholder sphere and
literally *is* the fish's rendered position (`FishFightController` holds no RealityKit/entity state
at all — see `GAMEPLAY_ARCHITECTURE_V1.md` and the "Fish Species and Fight Simulation" section of
`SOFTWARE_ARCHITECTURE_DOCUMENT.md`). When a real fish mesh/animation replaces it, this guaranteed
dock-approach climb is the natural hook point for a "landed on the dock" animation trigger — `reelHook`
already has a single, well-defined moment (the `distance3D > 0.15` guard failing) where the fish is
considered to have arrived, rather than that being inferred indirectly from tension or distance
elsewhere.

## Status

Accepted, pending live confirmation — verified via `swiftc -typecheck` against the `World` target
(macOS) and via a `Shared`-only build against the `Rod` (iOS simulator) target's module (see the
matching `CHECKPOINT.md` entry), not yet played. `dockLiftSpeed = 3.5` is a hand-picked value (faster
than the player's own max reel speed, `3.0`) rather than one tuned against a live session.

------------------------------------------------------------------------

# ADR-043 --- Hook Lift Motion Targets a Dedicated Point, Not the Rod's Render Anchor

## Decision

`reelHook(deltaTime:)` and `driftHookAway(deltaTime:)` (ADR-042) moved the hook's near-zone
(within `hookLiftDistance`) lift phase, and `reelHook`'s catch/empty-retrieve resolution distance,
toward `controllerEntity.position` — i.e. `dockAnchorPosition`, `[0.22, 1.95, -2.1]`, the rod's
fixed camera-relative render anchor (ADR-019). Loading `dock_main.usdz` directly via
`Entity(contentsOf:).visualBounds(relativeTo: nil)` (not eyeballed) measured its real footprint as
X in `[-2.04, 2.04]`, Z in `[-4.5, 4.5]` — `dockAnchorPosition`'s XZ, `(0.22, -2.1)`, sits well
inside that footprint, not at an edge. Since the lift phase rises the hook from `waterHeight` (`0`)
up to `1.95` while its XZ converges on that interior point, the rise happened directly underneath
the dock's solid deck geometry, reading as the bobber clipping through the pier on lift.

Added `hookLiftTargetPosition: SIMD3<Float> = [0.22, 1.95, -4.7]` — same X/Y as
`dockAnchorPosition` (so the pull still reads as heading toward the held rod, and still finishes at
hand height), but Z pushed to `-4.7`, just past the dock mesh's own measured `-4.5` water-facing
extreme. `reelHook`/`driftHookAway` now compute horizontal distance, the lift-phase 3D direction,
and (in `reelHook`) the catch/empty-retrieve resolution threshold all against
`hookLiftTargetPosition` instead of `controllerEntity.position`. `dockAnchorPosition` and
`controllerEntity` are otherwise untouched — `updateRodPose()`'s rendering and `ensureFightDistance()`
(ADR-031's same-tick-instant-catch guard, left alone per ADR-042's own precedent) still use the rod's
real render position.

## Rationale

Reported directly after playtesting ADR-042's fix: "waktu ngangkat, kayanya masih overlap sama pier
(maybe kurang ke depan dikit?)" (when it lifts, it seems to still overlap with the pier — maybe it
needs to be a little more forward?). Recorded as a TODO in the matching `CHECKPOINT.md` entry rather
than fixed blind at the time, pending a look at the dock's actual geometry per this project's own
established pattern of checking the asset directly instead of guessing (see e.g. the tree-orientation
and shoreline-density fixes in `EnvironmentSceneBuilder.swift`).

Reusing `dockAnchorPosition` conflated two different concerns that ADR-019 already treats as
separate elsewhere (rod-root render position vs. hook gameplay motion): a point chosen for where the
rod visually sits in the player's hand is not the same as the point gameplay motion should converge
on, and here they need to differ specifically because the render anchor happens to sit inside the
dock's own solid geometry. `hookLiftTargetPosition` keeps that separation explicit — a second,
motion-only anchor, matching the player's own diagnosis (needs to be further forward, i.e. further
out over open water) and the measured mesh bounds (which independently confirm `dockAnchorPosition`'s
Z is well short of the dock's actual water-facing edge).

Both `hookLiftDistance` (1.0 m, unchanged) and the new `-4.7` Z value are still hand-picked relative
to the *measured* mesh extreme (`-4.5` plus a 0.2 m clearance margin), not validated against a live
session — the mesh only yielded one undifferentiated bounding box (`dock_main.usdz` has no separate
deck/railing submeshes to bound individually), so `-4.7` is the most defensible value obtainable
without an interactive Blender pass, not a claim that it's exactly where the pier's walkable edge
ends.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` against both the
`World` (macOS) and `Rod` (iOS simulator) targets only (see the matching `CHECKPOINT.md` entry), not
yet played.

------------------------------------------------------------------------

# ADR-042 --- Reel-In Motion Stays at Water Height Until Near the Dock

## Decision

`WorldViewModel.reelHook(deltaTime:)` and `driftHookAway(deltaTime:)` previously moved the hook
in a straight 3D line toward/away from `controllerEntity.position` (`dockAnchorPosition`,
`[0.22, 1.95, -2.1]`) every tick. Since the hook sits at `waterHeight` (`0`) after a splash and the
rod is held at `y = 1.95`, that 3D vector always had a large vertical component from the very first
reeling tick — the bobber visibly rose and climbed diagonally toward the rod immediately, instead of
staying at the water's surface until close to shore.

Added `hookLiftDistance: Float = 1.0` (meters, horizontal). Both functions now branch on the
*horizontal* (X/Z) distance from the hook to the rod:

```text
horizontalDistance > hookLiftDistance  -> move/drift horizontally only; pin hookEntity.position.y
                                            to waterHeight every tick
horizontalDistance <= hookLiftDistance -> move/drift in full 3D (the original behavior), so the
                                            hook rises the rest of the way up to the rod
```

**Catch/empty-retrieve resolution also switched basis.** `reelHook`'s terminal `guard` — previously
`distance > 0.12` on the full 3D distance — now checks the same `horizontalDistance > 0.12`. The
full-3D version required the hook to also close the ~2 m vertical gap up to `dockAnchorPosition`'s
height before resolving, i.e. effectively requiring it to reach the rod's exact held position: doing
this diagonally, then only just barely still counting once it got close (a hook still ~1.9 m below the
rod but 12cm out).  Using horizontal distance means the catch/retrieve resolves once the hook is close
to the dock's edge horizontally, matching how the motion itself now reads — arriving at the water's
edge in front of the pier, not climbing all the way up to hand height.

`ensureFightDistance()` (the ADR-031 same-tick-instant-catch guard) was left untouched — it already
only ever fires in a rare edge case (a bite landing while the hook is already extremely close to the
rod in full 3D, effectively requiring the hook to already be in the near/lift zone), and its behavior
is unaffected either way by this change.

## Rationale

Reported directly: "kalo reel, arah si bobber nya masih diagonal langsung ke arah rod. seharusnya,
bobber ngikut di dasar air aja sampai akhir deket rod, baru keangkat (jadi ikan sukses ditangkep
bukan pas bobber hit base coordinate alias tempat rod, tapi begitu di depan pier dikit)" (when
reeling, the bobber's direction still goes diagonally straight toward the rod. It should instead
follow along the water's surface until it's near the rod at the end, then finally get lifted — so
the fish counts as caught not when the bobber hits the base coordinate, i.e. the rod's position, but
as soon as it's a bit in front of the pier).

Root cause confirmed by reading `reelHook`/`driftHookAway` directly: both used the raw
`controllerEntity.position - hookEntity.position` vector for every step, with no distinction between
the horizontal (across-the-water) component and the vertical (out-of-the-water) component. Splitting
movement into a horizontal-only phase (most of the reel-in) and a full-3D phase (only the last
`hookLiftDistance` meters) matches how a real fishing retrieve reads — the line and bobber travel
across the water's surface, and only come up out of the water right at the end, near the angler.
`driftHookAway` got the same fix for consistency: without it, a resisting fish would have dragged the
hook down and away in 3D too, which — since "away from the elevated rod" has a downward component —
would have pulled the hook visibly *below* the water plane while the player wasn't reeling, an
unrelated but symmetric instance of the same underlying bug.

`hookLiftDistance` (1.0 m) and the reused `0.12` m catch-threshold constant are both hand-picked, not
measured against the dock/water asset geometry — this is a first pass at the reported motion issue,
not a claim that 1.0 m is the exact right distance for the lift to look natural once played.

Status: Accepted, pending live confirmation — verified via `swiftc -typecheck` only (see the
matching `CHECKPOINT.md` entry), not yet played.

------------------------------------------------------------------------

# ADR-041 --- Nearby Interaction Is Present but Not Load-Bearing for V1 Gameplay

## Decision

Confirmed by direct code audit, not inference from docs: Rod still owns and runs a Nearby
Interaction session exactly as ADR-014 describes (`NearbyInteractionManager.swift` populates
`SpatialState.directionX/Y/Z`/`distance`, which flow into `RodState` and transmit every ~30 Hz
sample), but **no gameplay, rendering, or connection-gating code path anywhere in Rod or World
reads those fields.** Grepped every plausible consumer:

- `WorldViewModel.updateRodPose()` sets `controllerEntity.position` from the fixed
  `dockAnchorPosition` constant and `controllerEntity.orientation` from `RodState.orientation`
  only (ADR-019) — zero reference to `rodState.distance`/`direction`.
- `CastResolver`/`RodMotionInterpreter` derive cast direction/power from corrected orientation and
  (ADR-033) live rig geometry — zero reference to NI's spatial fields.
- `hookDistanceFromRod()`, which drives the ADR-039 fight/escape-distance mechanic, is
  `simd_length(controllerEntity.position - hookEntity.position)` — a RealityKit scene-space
  calculation between two entities, unrelated to NI's real-world ranging.
- `connectionState` (which gates whether the player can start fishing) is set purely from the
  CoreBluetooth transport's own `onStateChange` callback; `spatialStatus` (NI's own status) is a
  separate published property read in exactly one place on each device — a debug status/value row
  in `ContentView.swift` (Rod: `spatialStatus` label plus the direction/distance debug rows;
  World: the same distance/direction debug rows). Nothing gates on it.

**Decision: leave the Nearby Interaction code in place** (Rod keeps owning the session per
ADR-014; `SpatialState`/`RodState.directionX/Y/Z`/`distance` are unchanged) rather than removing
it — a removal is a separate, larger-scope decision not made here. This ADR only corrects
`AGENTS.md`'s prior "Casting State and Transform Contract" wording, which claimed *"Nearby
Interaction spatial distance/direction remain the rod's spatial transform source."* That statement
was accurate before ADR-019, when `updateRodPose()` did position the rod root from live NI
distance/direction — ADR-019 deliberately decoupled that (to fix the rod visibly moving during a
cast) and nothing since has restored NI to that role. The doc line was never updated to reflect
its own project's later decision.

## Rationale

Raised directly by the player after reviewing a separate chat's analysis questioning whether NI
could ever be "load-bearing" given CoreBluetooth's RSSI-based ranging can't match NI's UWB
precision/direction — a fair technical point, but the actual question that mattered was whether
today's V1 gameplay uses NI's precision at all, not whether it theoretically could. Player's own
framing once the audit above confirmed it doesn't: **"NI awalnya akan dipakai, tapi ternyata
transport protocol pakai CoreBluetooth aja cukup untuk ngirim data sehingga spatial controller
belum akan dipakai di fase development ini"** (NI was originally going to be used, but it turned
out CoreBluetooth transport alone is enough to send data, so the spatial-controller aspect isn't
going to be used in this phase of development). This project's own name and `ADR-015`'s long-term
vision ("reusable spatial controller framework" for a tennis racket, golf club, sword, etc.) are
explicitly built on NI's distance/direction sensing being load-bearing eventually — this ADR does
not retire that vision, it records that the *current* V1 fishing gameplay never ended up needing
it, and that the Nearby Interaction plumbing is fully intact and available the moment a future
feature (e.g. a physical-proximity-driven effect) actually calls for it.

Explicitly not decided here: whether to ever remove NI, whether `AGENTS.md`/`CLAUDE.md`'s framing
of this project as a "spatial controller" PoC should change, or whether NI's debug rows should be
trimmed. Documentation-only correction of one stale claim, not a scope change.

Status: Accepted

------------------------------------------------------------------------

# ADR-040 --- World-Side Audio Mirrors the Rod Haptics Router

## Decision

Added the game's first sound effects, wired entirely on the World side. A `SoundManager` +
`FishingSounds` pair (`World/World/Audio/`) structurally mirrors Rod's `HapticManager` +
`FishingHaptics` (`Rod/Rod/Haptics/`): one preloaded `AVAudioPlayer` per sound primitive
underneath, one `handle(_ event: FishingEvent)` switch on top. Audio is presentation, so it stays
out of `Shared` and never touches the transport — Rod keeps haptics only, no phone-side audio.

`WorldViewModel` funnels every World-emitted `FishingEvent` through a single `emit(_:)` method
that calls both `sounds.handle(event)` and the existing `send(.fishingEvent(event))`, so sound
and Rod's haptic trigger can never drift out of sync with each other. `.cast` has no
World-emitted `FishingEvent` (Rod generates it locally from motion, per the existing
Rod-local/World-emitted split in `FishingEvent`), so the cast sound is triggered directly from
`launchHook(solution:)` via `sounds.castLaunched()` instead of going through the funnel.

The reel loop is **frame-driven, not event-driven**: `WorldViewModel.tick(deltaTime:)` calls
`sounds.updateReelLoop(active:)` every tick based on `rodState.action`/`hookPhase`, so an
empty-line retrieve during `.hookInWater` (no fish hooked yet) still gets the reel sound, not
just an active fight — matching what a player actually hears when reeling, independent of
whether a fish happens to be on.

`AVAudioPlayer` was chosen over RealityKit's spatial `AudioResource`/`AudioPlaybackController`:
none of the current sounds (UI clicks, ambience, splash/bite/catch one-shots) need 3D
positioning. Spatializing the hook-splash/reel sounds to the hook entity's world position is a
plausible future upgrade, not needed for this pass.

`AVAudioSession` is iOS-only, so `SoundManager`'s session setup is wrapped in `#if os(iOS)`
(`.ambient` category with `.mixWithOthers`) — macOS needs no session configuration to play audio
under its sandbox. `.ambient` was picked over `.playback` so game audio respects the iOS silent
switch by default; revisit if that turns out to be the wrong default for this game.

Two gaps left deliberately open, both user-confirmed for this pass: `fishEscaped`/`lineBreak`
have no dedicated recorded asset yet, so they reuse the hook-splash one-shot (reads as the fish
darting off) rather than staying silent; and the level-up banner has no sound at all — if one is
added later, the trigger point is `FishFightController.levelUpAnnouncement` becoming non-nil,
observed the same place `ContentView` already shows the banner.

## Rationale

Mirroring Rod's haptics router structure (rather than inventing a new shape) means anyone who
already understands `FishingHaptics.handle(_:)`'s switch, `stopInterest()`/`stopFight()`
belt-and-suspenders cleanup, or the `FishFightConfig`-driven band parameters can read
`FishingSounds` with no new mental model. Keeping the `emit(_:)` funnel as the single place both
systems get told about an event was a direct decision to prevent the two feedback channels
(haptic on Rod, audio on World) from silently diverging over time as new events get added,
rather than trusting every call site to remember to fire both a `send` and a sound.

Assets moved from a repo-root `SFX/` folder (untracked, spaces/parentheses in filenames, one
stray Ableton `.asd` analysis file) into `World/World/Assets/SFX/` with clean snake_case names
matching the `Sound` enum's raw values — both Xcode projects already use Xcode 16 synchronized
root groups (`PBXFileSystemSynchronizedRootGroup`, `objectVersion 77`), so no `.pbxproj` resource
entries were needed; anything under `World/World/` bundles automatically, the same way the
existing `Assets/Environment/*.usdz` files do.

## Verification

-   `cd Shared && swift build` — clean; Shared is untouched by this change.
-   `git diff --check` — no whitespace errors.
-   `xcodebuild -workspace CtSPoC.xcworkspace -scheme World -destination 'platform=macOS' build`
    (with `CODE_SIGNING_ALLOWED=NO`, since this machine has no matching "Mac Development"
    certificate) — builds clean after one real fix: `FishingSounds.init`'s default parameter
    value `SoundManager()` was rejected by the compiler ("call to main actor-isolated
    initializer... in a synchronous nonisolated context") because World's target sets
    `-default-isolation=MainActor` project-wide, and default-argument expressions aren't
    automatically isolated to the enclosing type's actor. Fixed by dropping the default and
    constructing `FishingSounds(sounds: SoundManager())` explicitly in `WorldViewModel`'s stored
    property initializer, which — unlike a parameter default — runs correctly isolated as part of
    the actor's own init.
-   Confirmed all eight `.wav`/`.mp3` files landed in the built `World.app/Contents/Resources/`.
-   Launched the built `World.app` directly (`open .../World.app`) and confirmed it stays running
    with no crash and no audio-related errors in the system log for the main-menu screen, where
    the ambience loop starts immediately.
-   Not run: a full manual gameplay pass with Rod actually connected (cast/splash/bite/reel/catch/
    escape/line-break audible in sequence, loop start/stop timing feel, rapid-retrigger behavior).
    iOS-device audio behavior — the silent switch, `AVAudioSession` interruptions from phone calls
    or backgrounding — is entirely unverified and needs on-device testing.

------------------------------------------------------------------------

# ADR-039 --- Fight Difficulty Pass: Tug-of-War, Distance Escape, Tension Haptics, Fight Camera

## Decision

Five related changes making the fight harder and more dramatic, all requested together after
live play ("rasanya masih terlalu gampang dapetin ikan baik fish A, B, C, bahkan Scott"):

**Longer casts.** `WorldViewModel.castSpeed` 3.6 → 5.0 (max-power ballistic range ~13 m → ~24 m);
`FishFightController.maxExpectedCastDistance` 10 → 20 so the size-ceiling normalization keeps
spanning the real achievable range.

**Camera follows the fight.** `updateCameraFollow()` — previously flight-only — now also tracks
the hook through `.fishOnHook`/`.reeling`, so the whole tug-of-war is watched up close. Every
other phase (including `.result`) still snaps back to the player pose.

**Reel tension climbs faster — revised.** `baseReelTensionRate` 0.5 → 0.85 first, then → **0.55**
after live testing showed 0.85 made even `fish_a` (the weakest tier) nearly impossible to land
without immediately overshooting to line-break: at `reelSpeed` 1.0, `reelPull` (0.85) so far
exceeded `fish_a`'s `effectiveFishPullRate` (~0.15–0.20 depending on the roll) that tension went
from `initialTension` (0.5) to 1.0 in well under a second, regardless of species. 0.55 keeps a
real risk at full reel speed (~1.25–1.44 s to snap against `fish_a`, worked out by hand — see the
Rationale) while making moderate reeling (`reelSpeed` ~0.6) give a comfortable ~3 s window and
light reeling (~0.3) roughly neutral, so modulating reel speed is a real, learnable skill instead
of "any reeling overshoots."

**Real tug-of-war + distance escape.** `basePullSpeed` 0.4 → 1.0, and `reelHook()` now subtracts
`fishFight.fishPullSpeed` from the player's reel speed — net-negative means the fish gains line
*while the player is actively reeling*. `updateFight` gained a `hookDistance:` parameter: the
first fight tick's distance becomes a baseline, and if the fish takes more than
`escapeDistanceAllowance` (6 m) of line beyond it, the fight resolves `.escaped` (the "spooled"
failure). Weak reeling is now a losing strategy against a strong fish rather than a slow
guaranteed win.

**Escape now resets to `.idle`, not `.hookInWater`.** Both `FightFailure` cases in
`resolveFightFailure` now disable the hook and go to `.idle` (a fresh cast is required) — matches
`.lineBreak`'s existing treatment, which `.escaped` previously did not get. Requested directly:
"kalo tension kerendahan (slack), reset langsung bobber ke posisi awal (alias ga hookInWater
lagi)." A slack-tension escape and a distance-spooled escape both report as the same
`FightFailure.escaped` case, so both get this treatment — there was no clean way to give one but
not the other without threading a failure subtype through, and there's no indication only one of
the two should behave differently.

**All fight-tuning numbers extracted into `FishFightConfig` (Shared, new).** `initialTension`,
`baseFishPullRate`, `baseReelTensionRate`, `basePullSpeed`, `escapeDistanceAllowance`, the two
`tensionBand` thresholds, and all nine Rod haptic-band parameters (interval/intensity/sharpness
× low/medium/high) moved out of private constants scattered across `FishFightController` (World)
and `FishingHaptics`' `FightBand` enum (Rod) into one `Codable`/`Equatable` struct in Shared, with
every field documented inline. `FishFightController.init` and `FishingHaptics.init` both take a
`config: FishFightConfig = FishFightConfig()` parameter — existing call sites (`FishFightController()`,
`FishingHaptics()`) are unaffected, and both classes now read the *same* config instance's values
so gameplay difficulty and haptic feel can't silently drift apart from each other.
`maxExpectedCastDistance` deliberately stayed a private `FishFightController` constant, not part
of the config — it's cast physics (tied to `WorldViewModel.castSpeed`), not fight tuning.

**Tier differentiation was too weak — resistance now has its own multipliers.** Both
`effectiveFishPullRate = baseFishPullRate * (1 + resistance)` and `fishPullSpeed = basePullSpeed *
(1 + resistance * 0.5)` used an implicit multiplier of `1.0`/`0.5` on `resistance`, so
`resistance`'s contribution was smaller than (pull rate) or comparable to (pull speed) the base
term itself — every species/tier produced a similar net tension rate regardless of how tough it
was supposed to be. `FishFightConfig` gained three new fields:
`pullRateResistanceMultiplier` (3.0), `pullSpeedResistanceMultiplier` (1.8), and
`escapeAllowanceResistancePenalty` (3.5, with a `minEscapeDistanceAllowance` floor of 2.0 m so it
can never over-tighten). Formulas become:

```text
effectiveFishPullRate = baseFishPullRate * (1 + resistance * pullRateResistanceMultiplier)
fishPullSpeed         = basePullSpeed * (1 + resistance * pullSpeedResistanceMultiplier)
effectiveEscapeAllowance = max(minEscapeDistanceAllowance,
                                escapeDistanceAllowance - resistance * escapeAllowanceResistancePenalty)
```

At `resistance == 0` (any tier's smallest possible roll) all three formulas are unchanged and
identical across every species — a small individual is weak regardless of species, which is
correct and not the thing being fixed. At a max-size roll, the new multipliers produce a real
spread (worked out by hand, net tension rate at full reel speed): `fish_a` ~+0.24/s (comfortable,
~2 s to snap), `fish_b` ~+0.15/s (~3.3 s, noticeably tighter), `fish_c` ~+0.06/s (~8 s, razor-thin
margin), `scott` ~**-0.03/s** — full-speed reeling alone can no longer even hold Scott's line,
forcing genuine tension modulation rather than "hold the reel button." The escape allowance
similarly tightens from ~4.8 m (`fish_a`) down to ~2.7 m (`scott`), so a powerful fish also
punishes a slack moment harder, not just a sustained-tension mistake.

**Continuous tension haptics on Rod.** `FishingEvent` gained `reelTensionLow/Medium/High`.
`FishFightController.tensionBand` derives the band from `lineTension` (< 0.55 low, 0.55–0.8
medium, ≥ 0.8 high); `WorldViewModel.syncTensionBand()` (every tick) sends an event only on band
*transitions* — no raw-tension streaming over the reliable World→Rod path. Rod's
`FishingHaptics` stores the band and pulses continuously at band-specific rhythm/intensity
(spaced 0.5 s taps → regular 0.28 s → rapid 0.11 s), reusing the same recurring-callback pattern
as `interestPulse`. Cleared by every fight-ending event and, belt-and-suspenders, by
`stopFight()` when `hookPhase` leaves the fight phases — mirroring exactly how the interest
pulse is kept from going stale. This implements `GAMEPLAY_ARCHITECTURE_V1.md`'s
"resistance through rhythm as well as intensity" haptic spec, driven by live tension rather
than static fish size — a stronger fish reaches the higher bands faster and holds them longer,
so the rhythm still communicates the fish, but through the fight's actual state.

## Rationale

Requested directly: "rod casting nya kurang jauh"; "ketika hook kena fish, camera langsung geser
lagi ke hook dong biar proses reel nya jadi lebih dramatis"; "kasih getaran haptics continuous
juga di hp untuk reel meter (ini yang low medium high haptics)"; "masih terlalu gampang dapetin
ikan... Bikin lebih susah lagi dengan reel meter lebih cepet naik ke high tension"; "perlu ada
juga mechanism dimana ikannya bisa escape dari reel karena kejauhan."

The tug-of-war change is what makes the distance escape meaningful: with the old code the hook
only ever moved toward the rod while reeling, so no amount of fish strength could create
distance danger during active play — the escape threshold would only ever fire while the player
stood idle, which the slack-tension timer already punishes. Subtracting pull speed from reel
speed turns distance into a live resource both sides fight over, which is also exactly what the
newly-following camera is pointed at.

The 0.85 → 0.55 correction was reported directly after playing: "kayanya reel nya terlalu susah
deh, it's even impossible untuk grab fish A tanpa tensionnya ketinggian." Worked out by hand
(`baseFishPullRate(0.15) * (1 + 0.35 * sizeRatio)` for `fish_a`'s resistance/size range,
`reelSpeed * baseReelTensionRate` for reel pull, time-to-snap = `0.5 / net` since a bite starts
at `initialTension`):

```text
                        reelSpeed=0.3   reelSpeed=0.6   reelSpeed=1.0
0.85 (first pass)       overshoots      ~0.9s to snap   ~0.7s to snap
0.55 (corrected)        ~neutral/safe   ~2.8-3.9s       ~1.25-1.44s
```

0.55 was chosen so full-speed reeling stays a real, if generous, risk rather than either
"impossible to avoid" (0.85) or "no risk at all" (something closer to the original 0.5, which is
what made the fight feel trivial before this ADR started).

The config extraction followed directly from the same conversation: "bisa ga dibikin di dalam
config file beserta docs nya, agar aku bisa tuning manual?" (can this go in a config file with
docs, so I can tune it manually?) — rather than hand this specific 0.85→0.55 correction back as
another one-off edit, every number in the same tuning space moved somewhere the player can adjust
directly without needing another round-trip through code changes. `FishFightConfig`'s own doc
comments are the primary reference while tuning; this ADR is the record of *why* the current
defaults are what they are.

Every number here — reel/pull rates, the 6 m escape allowance, band thresholds, haptic
intervals — is a first-pass, hand-reasoned default, not a play-tested one. That's the explicit
point of making them config: the player is expected to keep adjusting them directly.

The resistance-multiplier fix was reported directly, in the same message that confirmed 0.55
solved the "impossible" problem: "sepertinya udah cukup susah, namun, tingkat loncatan dari fish
A - B - C - Scott masih kerasa gaada bedanya" (seems hard enough now, but the difficulty jump
from Fish A to B to C to Scott still doesn't feel like there's a difference). Diagnosed by working
the same net-tension-rate formula used for the 0.55 correction across all four species side by
side (see the Decision section's table) — confirmed the spread was only ~35% between the weakest
and strongest tier at full reel speed, with every tier sharing an identical floor, which is
exactly a "no real difference" symptom. The fix is a config change like everything else in this
ADR, not a code restructure: three new multiplier fields, same formulas otherwise.

Status: Accepted, pending live confirmation (see the matching `CHECKPOINT.md` entry).

------------------------------------------------------------------------

# ADR-038 --- Rod Owns the Session Start/End Boundary, Not World

## Decision

**`RodState` (Shared) gains `isFishing: Bool`**, streamed continuously alongside everything else
in the existing ~30 Hz `.state` message — no new message type. Set from `RodViewModel.isFishing`
(already existed locally, gating cast/reel gesture reporting; now also transmitted) in all three
`RodState` construction sites (`publishState()`, `updateAction()`, and the `.idle`-hookPhase
reset in `handle(_:)`).

**`WorldViewModel.screen` (`.mainMenu`/`.playing`, ADR-036) is now driven by `RodState.isFishing`,
not a World-side button.** `handle(_:)` compares `state.isFishing` against the previous
`rodState.isFishing` on every incoming `.state` message: rising edge → `screen = .playing`;
falling edge → `returnToMenu()` (now `private`, and no longer gated to `hookPhase == .result` —
the player can press "End Fishing" on Rod at any point, not just after a catch, so it resets
whatever fight/hook state was in progress: hook velocity zeroed, hook entity disabled,
`fishFight.resetForNewCast()`, `hookPhase` back to `.idle`, *then* `screen = .mainMenu`).
`startGame()` (the old button handler) is deleted — nothing calls it anymore.

**Fail-safe on disconnect.** Since `screen` now depends entirely on `.state` messages continuing
to arrive, a genuine Rod disconnect mid-session would otherwise leave `screen` stuck on
`.playing` forever (no more messages ever arrive to flip it, and there's no controller left to
press "End Fishing" on). `transport.onStateChange` now also calls `returnToMenu()` on
`.disconnected`/`.failed`, not just handling `.ready`'s existing `hookPhase` resync.

**`World/World/Views/MainMenuView.swift`** loses its "Start Fishing" button entirely — it's now
purely a status display (title + a status row: spinner/text per `ConnectionState`, or once ready,
"Press \"Start Fishing\" on Rod to play"). **`World/World/Views/ResultView.swift`** loses its
"Return to Menu" button (added one task ago, in ADR-036) for the same reason: with `screen` now
reactively following `isFishing`, a World-side button forcing `screen = .mainMenu` would just get
overridden back to `.playing` by the very next `.state` message, since Rod would still think
`isFishing == true`. Only "Continue Fishing" remains.

**Rod's `ContentView.swift`**: the three-button stack (`Start Fishing` / `Calibrate` /
`End Fishing`, the latter two previously always visible, Start/End both present but
disabled/enabled oppositely) becomes one `@ViewBuilder` button that swaps its entire
label/action/style based on `isFishing` — `Start Fishing` (`.borderedProminent`, disabled until
calibration is complete) when not fishing, `End Fishing` (`.bordered`) once it is. Calibrate
moves out of that stack into a `ToolbarItem(placement: .topBarTrailing)` — the phone screen's
top-right corner — using the same `calibrationButtonTitle` computed property as before (no
duplicated logic), still disabled under the same conditions
(`!hasMotionSample || isFishing`).

## Rationale

Requested directly, with the reasoning stated up front: "instead of controller di world yang
harus press button untuk mulai mancing, ganti ke phone aja. status di world mungkin 'press
\"start\" on rod to play'. dan di rod pun bukan start fishing atau end fishing [sekaligus], tapi
start fishing, terus ketika mancing ada button end fishing buat balik ke main menu. recalibrate
jangan di tengah lagi, tapi geser ke pojok kanan atas dari rod screen" (instead of the controller
in World having to press a button to start fishing, change it to the phone. World's status
should read "press start on rod to play." And on Rod, not Start and End Fishing at once — just
Start Fishing, then once fishing, an End Fishing button to go back to the main menu. Recalibrate
shouldn't be in the middle anymore, move it to Rod's top-right corner).

This is a direct extension of `GAMEPLAY_ARCHITECTURE_V1.md`'s own core principle — "Rod is an
input device. World is the game" — to the session boundary itself, not just to gameplay input:
previously, starting/ending a fishing session was the one control still routed through World
(via `MainMenuView`'s button and, briefly, `ResultView`'s "Return to Menu"), which sat oddly
against a design where the player's attention and hands are meant to stay on the physical Rod
the entire time. Making Rod authoritative and World purely reactive removes that inconsistency —
and removing World's competing buttons wasn't optional once `screen` became reactive to
`isFishing`: keeping them would have created a button that visibly worked for one frame and then
silently reverted, which is worse than not having it.

Status: Accepted, pending live confirmation. See the matching `CHECKPOINT.md` entry.

------------------------------------------------------------------------

# ADR-037 --- Fish Tiers and a Three-Level Catch-Count Progression System

## Decision

**`FishSpecies` (Shared) gains a `tier: FishTier` field.** `FishTier` is a new enum (`.small`,
`.medium`, `.big`, `.boss`) recording which progression tier gates a species' availability —
matching `GAMEPLAY_ARCHITECTURE_V1.md`'s own "Each fish species owns static data: Species ->
Weight Range -> Length Range -> Resistance Range -> Value -> Difficulty," which already called
for a difficulty/tier-like field this model didn't have yet.

**`FishCatalog` (World) grows from one species to four**, one per tier: `fish_a` (`.small`,
unchanged), `fish_b` (`.medium`), `fish_c` (`.big`), `scott` (`.boss`). `randomSpecies()` becomes
`randomSpecies(unlockedTiers: Set<FishTier>)`, filtering the pool to only tiers the player has
unlocked (falling back to `all[0]`/`fish_a` — always unlocked — if the filtered pool is somehow
empty, so a bite can never fail to resolve a species).

**New `World/World/Gameplay/ProgressionStore.swift`**, persisted to `UserDefaults` the same way
`FishRecordStore` is. Tracks cumulative catches per tier and derives the current level:

```text
Level 1 (start):        .small catchable
-> 10 small caught  ->  Level 2: .medium also catchable
-> 10 medium caught ->  Level 3: .big AND .boss (Scott) also catchable
```

`.big`/`.boss` catches are counted too but don't unlock anything further — there's no Level 4
defined yet. `unlockedTiers` (consumed by `FishCatalog.randomSpecies(unlockedTiers:)`) and
`progressTowardNextLevel: (caught: Int, needed: Int)?` (`nil` once level 3 — nothing left to
progress toward) are both derived, not separately stored.

**`FishFightController`** takes a `ProgressionStore` the same way it already takes a
`FishRecordStore` (injectable, defaulted). Publishes `currentLevel: Int` and
`levelUpAnnouncement: String?` (player-facing text, set the instant a catch crosses a threshold,
cleared by the new `dismissLevelUpAnnouncement()`) and passes through
`progressTowardNextLevel` for the HUD. `resolve(outcome:)`'s existing `.caught` branch — already
where `recordStore.recordCatch` and star/coin calculation happen — now also calls
`progressionStore.recordCatch(tier: species.tier)` and compares the returned level against
`currentLevel` to detect the transition.

**World HUD**: the existing "Caught" `GroupBox` gains a "Level N · x/10 to next tier" row. New
`World/World/Views/LevelUpBannerView.swift` — a dismissible toast pinned to the top of the
screen (not a blocking modal, and not auto-fading, so a "Scott has appeared" moment can't be
missed by looking away at the wrong second) — shown whenever `levelUpAnnouncement` is set. It can
appear stacked above `ResultView`, since the catch that crosses a tier threshold is still a
normal catch too; the two don't gate each other.

## Rationale

Requested directly, with the exact thresholds and unlock structure specified: "Level 1: after
catch 10 small fish, u can catch more medium fish. Level 2: after catch 10 medium-sized fish, u
can catch more big fish. Level 3: muncul scott dan kayak ngasih perintah untuk nangkap dia"
(Scott appears and it's like giving an order to catch him). Species stat scaling was left
explicitly loose: "parameter fish nya nanti di ubah lagi seiring berjalannya game, yang jelas
semakin tinggi level ikan, semakin susah dari sisi berat, length, dan resistance saat
reelingnya" (fish parameters will be adjusted again as the game goes on — what's firm is that
higher tier means harder in weight, length, and reeling resistance). `fish_b`/`fish_c`/`scott`'s
weight/length/resistance/value in `FishCatalog` are accordingly rough scale-ups from `fish_a`,
not balanced numbers — placeholders satisfying "harder at every tier," explicitly expected to be
retuned later, not a claim of final balance.

`.boss` was kept as its own tier rather than folding Scott into `.big` at a higher weight,
because the player's framing of Scott ("appears and gives an order to catch him") reads as a
distinct, singular, narratively-flagged encounter — not just another random roll from the same
pool as every other big fish. Unlocking `.big` and `.boss` together at Level 3 (rather than
requiring a fourth tier/threshold) matches the player's own three-level spec exactly: three
levels were specified, not four, so Scott had to enter the pool at the same unlock as `.big`
rather than gating him further out.

Because `resolve(outcome:)` already owned the one place a successful catch is processed
(star/coin/record-keeping), wiring progression in alongside it — rather than as a separate
tracked step — keeps the "a catch has consequences" logic in one place instead of splitting it
across two call sites that would need to stay in sync.

Status: Accepted, pending live confirmation. See the matching `CHECKPOINT.md` entry for what's
verified (typecheck only) versus not yet played.

------------------------------------------------------------------------

# ADR-036 --- World Main Menu, Persisting the Scene Across Menu/Play Transitions

## Decision

`WorldViewModel` gains a `Screen` enum (`.mainMenu`, `.playing`) and a `@Published private(set)
var screen`, defaulting to `.mainMenu`. Two new methods gate the transition in both directions:

```text
startGame()    — Main Menu's "Start Fishing" button. No-ops unless connectionState is
                 .ready or .streaming: "the player cannot continue until the controller
                 is available" (GAMEPLAY_ARCHITECTURE_V1.md's Connect step).
returnToMenu() — Result screen's new "Return to Menu" button (alongside the existing
                 "Continue Fishing"). Guarded to hookPhase == .result, same as
                 continueFishing(); also resolves hookPhase back to .idle.
```

**`ContentView`'s RealityKit scene (`content`) is never conditionally mounted/unmounted on
`screen`.** It stays alive for the whole app session; `MainMenuView` and `ResultView` are
overlays drawn on top of it in the same `ZStack`, shown or hidden based on `viewModel.screen`/
`hookPhase`. `content`'s existing `.onAppear { viewModel.start() }` is unchanged and still fires
immediately when `ContentView` first appears — the transport connection begins in the background
while the Main Menu is on screen, so by the time the player presses "Start Fishing" the
connection is often already `.ready`, and the (expensive, USDZ-asset-heavy) environment/rod rig
never needs to reload just because the player returned to the menu and started again.

New `World/World/Views/MainMenuView.swift`: title, subtitle, a "Start Fishing" button disabled
until `connectionState` is `.ready`/`.streaming`, and a status row (spinner + text, or a
checkmark once connected) reflecting every other `ConnectionState` case. Solid black background,
not a translucent overlay — the player shouldn't see gameplay rendering through a title screen.

`ResultView` gains a second closure, `onReturnToMenu: () -> Void`, and a second button beneath
"Continue Fishing." `Return to Menu` does **not** disconnect Rod — the transport connection is
left running, consistent with `content` never being torn down.

## Rationale

Requested directly, immediately after wrapping up the CoreBluetooth transport migration: "gausah
commit sih, maybe sekarang saat yang tepat buat implement main menu dulu sesuai v1" (no need to
commit — maybe now's the right time to implement the Main Menu, per V1). This closes a gap
flagged repeatedly since ADR-029/the Result Screen sprint: `ResultView`'s doc comment and two
prior `SOFTWARE_ARCHITECTURE_DOCUMENT.md`/`CHECKPOINT.md` entries all noted "Return to Menu" was
skipped specifically because "there is no Main Menu yet to return to" — this ADR is what makes
that button meaningful rather than adding it in isolation.

Keeping `content` permanently mounted (menu/result as overlays, not a screen replacement) was a
deliberate choice over the more literal reading of "Main Menu screen" as its own fully separate
view hierarchy: `EnvironmentSceneBuilder.build()` loads and places on the order of 200 scattered
USDZ instances (per its own scatter-instance table) plus the dock/water/terrain/rod-rig assets —
re-running that on every menu round-trip during a single play session would be a real, avoidable
cost and a jarring reload for something conceptually as simple as "look at the menu again."

Status: Accepted, pending live confirmation. Not yet run on device/simulator — verified via
`swiftc -typecheck` only (see the matching `CHECKPOINT.md` entry). In particular, whether
`content`'s `RealityView` genuinely avoids re-creating the scene across a menu round-trip (rather
than SwiftUI treating the `ZStack` reordering as a reason to rebuild anyway) has not been
observed live, only reasoned about from `RealityView`'s documented `make`-once-per-identity
behavior.

------------------------------------------------------------------------

# ADR-035 --- Transport Replaced: MultipeerConnectivity to CoreBluetooth

## Decision

`Rod/Rod/Transport/TransportClient.swift` and `World/World/Transport/TransportHost.swift` are
fully rewritten on CoreBluetooth. No `import MultipeerConnectivity` remains anywhere in either
target. `TransportProtocol` (Shared) and `NetworkMessage` (Shared) are unchanged in shape —
this is an internal swap of what implements the protocol, not a redesign of who calls it.

**Roles**, matching the previous client/host split (Rod is the side that actively broadcasts
itself; World reacts to whichever peer shows up):

- **Rod = BLE peripheral** (`CBPeripheralManager`). Advertises one custom GATT service and three
  characteristics, all defined as plain UUID strings in `SessionConfiguration` (Shared) so both
  sides share the same identifiers without Shared importing CoreBluetooth:
  - `bleStateCharacteristicUUID` — Rod → World, **notify**, unreliable. Carries the ~30 Hz
    `RodState` stream.
  - `bleReliableOutCharacteristicUUID` — Rod → World, **indicate**, reliable. Carries
    `.discoveryToken`.
  - `bleCommandCharacteristicUUID` — World → Rod, **write-with-response**, reliable. Carries
    `.fishingEvent`/`.hookPhase`. (World writing into a characteristic Rod exposes is the only
    way a BLE central can push data to a peripheral — there is no "central notifies" primitive.)
- **World = BLE central** (`CBCentralManager`). Scans for the service, connects, subscribes to
  the two Rod → World characteristics, writes to the command characteristic.

**Message-flow inventory** (confirmed by grepping actual `.send(`/`case` call sites in
`RodViewModel.swift`/`WorldViewModel.swift` before writing any replacement code, per this
migration's own instructions — not assumed from memory): Rod sends `.state` and
`.discoveryToken`; World sends `.hookPhase` and `.fishingEvent`; World's `handle(_:)` only acts
on `.state`, ignoring everything else it receives (unchanged).

**Payload framing (`Shared/Sources/Shared/Protocols/BLEFraming.swift`, new).** A JSON-encoded
`NetworkMessage` may exceed one BLE packet once the ATT MTU is accounted for. `BLEFraming`
prefixes a payload with a 4-byte big-endian length header and splits it into MTU-sized chunks;
`BLEMessageReassembler` accumulates chunks fed from repeated delivery callbacks and yields
complete messages once enough bytes have arrived. Pure `Data` manipulation, no CoreBluetooth
import, so it's usable from both Rod's and World's transport layers without Shared taking on a
platform dependency. Verified correct via a standalone roundtrip test (single-chunk, multi-chunk,
sequential messages through one reassembler, empty payload, and coalesced multi-message delivery
— all pass) before being wired into either transport file.

**The unreliable (`.state`) path never fragments.** If an encoded state sample doesn't fit in one
packet, it's dropped outright rather than risking a desynced multi-chunk stream on a channel with
no delivery guarantee — a fresher sample is always ~33 ms away, matching the semantics
`NetworkMessage.requiresReliableDelivery`'s doc comment already documents for this path. The two
reliable paths (indicate/write-with-response) may fragment safely, since both have CoreBluetooth's
own per-packet acknowledgment: indicate via `updateValue` returning `false` until
`peripheralManagerIsReady(toUpdateSubscribers:)` fires, write-with-response via
`didWriteValueFor`/`error` per chunk. Both reliable sends are queued (FIFO, one logical message's
chunks fully drained before the next starts) so overlapping calls — e.g. two `.fishingEvent`s
sent close together — can't interleave and corrupt each other's chunk sequence.

**`@MainActor` on both transport classes and on `TransportProtocol` itself.** Both CoreBluetooth
managers are constructed with `queue: nil` (main queue), so every delegate callback already lands
on the main queue in practice; isolating the classes (and the protocol they conform to) to
`@MainActor` — matching `RodViewModel`/`WorldViewModel`, the only two callers — makes that
explicit and lets the mutable send-queue state be touched from both delegate callbacks and direct
`send()` calls without a separate lock, instead of leaving a real (if currently benign) data race
implicit. CoreBluetooth's delegate protocols are Objective-C and carry no such isolation of their
own; the conformances use `@preconcurrency` (the standard bridge for implementing an unisolated
ObjC delegate protocol from an actor-isolated Swift type), avoiding warnings that are hard errors
under Swift 6.

**Reconnection**: both sides keep trying continuously rather than requiring the caller to retry.
Rod leaves advertising running after a central unsubscribes (never stops it outside
`disconnect()`); World restarts scanning after any disconnect/failed-connect while still "wanting"
a connection. This matches the previous MPC behavior of leaving the browser/advertiser active
continuously once `connect()` was called.

**Platform entitlements.** `Info.plist` (`Rod`/`World`): removed `NSBonjourServices`. Both
targets' `project.pbxproj`: `INFOPLIST_KEY_NSLocalNetworkUsageDescription` replaced with
`INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription`. World specifically: `ENABLE_RESOURCE_ACCESS_
BLUETOOTH` flipped `NO` → `YES` — World runs sandboxed on macOS (`ENABLE_APP_SANDBOX = YES`), and
this build setting is the sandbox entitlement gate for CoreBluetooth; leaving it `NO` would have
silently blocked the central role at the OS level regardless of any code-level correctness. Also
tightened `ENABLE_INCOMING_NETWORK_CONNECTIONS`/`ENABLE_OUTGOING_NETWORK_CONNECTIONS` to `NO` —
grepped confirmed World has no other networking (`URLSession`/`Network.framework`), so these
existed only for MPC's local-network transport and are no longer needed.

## Rationale

Per the supplied migration brief (`MIGRATION_transport_to_corebluetooth.md`, not committed to the
repo, provided as a task document): a known MultipeerConnectivity bug on iOS 26 makes connection
pairing flaky specifically when Bluetooth is involved in establishing the connection — exactly
the Bluetooth-heavy, no-Wi-Fi-infrastructure scenario this project targets (fishing outdoors).
Apple's own migration guidance recommends moving off MPC's `NSStream`-dependent transport, and
CoreBluetooth's GATT notify/write model is a closer fit for this payload shape (small, frequent
messages at ~30 Hz) than MPC's general-purpose session/stream abstraction was.

Explicitly a **full replacement**, not a hybrid — the brief was clear that no MultipeerConnectivity
import should remain when this is done, confirmed by grep.

Status: Accepted, pending live-hardware verification (see the "Explicitly not yet verified"
section of the matching `CHECKPOINT.md` entry — this ADR records the design and code-level
verification that's actually complete; the migration brief's own test plan requires a Step 0/Step
1 baseline-vs-CoreBluetooth latency comparison on real devices with Wi-Fi off, which has not been
run).

------------------------------------------------------------------------

# ADR-034 --- Cast Direction Clamped to a Forward Cone, Bobber Doubled in Size

## Decision

`WorldViewModel.launchHook(solution:)` now clamps its computed horizontal
launch heading into a fixed cone around the camera's forward direction,
regardless of what upstream aim derivation (ADR-033's live rig-geometry
vector, or any future replacement) produces:

```text
corrected = rotatedAroundY(rawHorizontal, by: aimCorrectionAngle)
angle = atan2(corrected.x, -corrected.z)          // signed angle from -Z (straight ahead)
clamped = clamp(angle, -castConeHalfAngle, castConeHalfAngle)
horizontal = (sin(clamped), 0, -cos(clamped))
```

`castConeHalfAngle = 67.5°` (135° total cone width). The camera's forward
is a compile-time constant here, not a live basis vector — `makePlayerCamera()`
builds a static camera that never rotates dynamically (see its own
doc comment), so `(0, 0, -1)` is always correct without needing to read
camera state at cast time.

**`aimCorrectionAngle` (180°, revised from an initial 90° guess after
live-measuring the true raw angle).** ADR-033's rig-geometry-derived
aim, once actually cast on device, consistently put the bobber to the
*left* of the player's POV — a fixed rotational bias, not per-cast
noise — and cast distance dropped sharply from what it had been before
the cone clamp landed. A first 90° correction (below) turned out to be
a guess from the symptom alone, not a measurement, and the resulting
clamped landing coordinate gave no way to tell how far off the true
angle actually was — landing at the cone's boundary looks identical
whether the real angle is barely past it or wildly off. A debug-only
pair of unclamped angle readouts (`debugRawAimDegrees`/
`debugCorrectedAimDegrees`, `WorldViewModel`) exposed the real number:
raw aim measured at **-174°** — not a quarter-turn off, but almost
exactly **opposite** of forward. The tip-minus-root vector in
`launchHook(solution:)` points nearly straight backward when the player
casts forward; correcting for a near-180° inversion is a materially
different fix than nudging a 90° axis mismatch. `rotatedAroundY(_:by:)`
(a simple Y-axis rotation: `(x cosθ - z sinθ, y, x sinθ + z cosθ)`)
rotates the raw aim by `aimCorrectionAngle` — positive angles rotate
right, matching `clampedToForwardCone`'s own sign convention — *before*
the cone clamp, so the corrected heading lands inside the cone as
intended instead of constantly pinned at its edge. The measured -174°
leaves a small ~6° residual against an exact 180° correction, left
unaddressed pending the next live reading.

The hook (`World/World/ViewModels/WorldViewModel.swift`'s `makeSceneEntity()`)
also doubled in size: `.generateSphere(radius: 0.035)` → `radius: 0.07`.

## Rationale

Requested directly, immediately after ADR-033's fix: "gue masih gatau
direction si yellow bobber ini kemana, tapi yang jelas ga sesuai sama
apa yang gue mau. Bisa ga dibikin semacam limitation area jadi mau
kemanapun cast, cuma bisa ke arah depan, sekitar 135 derajat di depan
pov kamera?" (I still don't know where this yellow bobber's direction is
going, but it's clearly not what I want. Can you make a limitation area
so no matter where the cast goes, it can only go forward, about 135
degrees in front of the camera POV?) — plus, separately, "gedein juga
ukuran bobbernya by 2x" (also double the bobber's size).

This is a deliberate belt-and-suspenders addition on top of ADR-033
rather than a further attempt to prove the raw aim direction "correct":
the player's own framing ("I still don't know where it's going") calls
for a guaranteed bound on the outcome, independent of whether the
underlying rig-geometry derivation has some remaining, not-yet-
understood issue. A hard clamp to a forward-biased cone guarantees the
acceptance-criteria-relevant behavior (cast never lands behind or far to
the side of the player) even if the precise heading within that cone is
still being tuned. Doubling the bobber's visible size was requested
purely to make it easier to actually see and judge where it lands during
testing — not a gameplay-balance change.

`aimCorrectionAngle` followed from live testing with the camera-follow
debug aid: "ok kayanya ketemu masalahnya. bobbernya selalu loncat ke
kiri dari pov orang, dan cast distance nya jadi kecil banget dibanding
sebelumnya yang bisa jauh. Apa mungkin kalo kalo di define 'depan' itu
sekitar 90 derajat ke kanan dari titik cast sekarang bisa?" (I think I
found the problem. The bobber always jumps to the left of the player's
POV, and the cast distance became very small compared to before, when it
could go far. Could "forward" be redefined as about 90 degrees to the
right of the current cast point?) — a specific, testable correction
proposed directly from the reported symptom, implemented as stated. 90°
was a starting point derived from what was observed, not measured.

Live-testing that 90° value showed the landing coordinate pinned almost
exactly at the cone's -67.5° boundary — "Player facing: (0.00, -12.47),
Cast landed: (-11.52, -4.77). kan jauh" (that's really far apart) —
which could mean anything from "barely past the cone edge" to "wildly
off," since a clamp collapses both to the same result. Rather than keep
guessing against a masked number, added the unclamped
`debugRawAimDegrees`/`debugCorrectedAimDegrees` debug readout so the
next cast would report the true angle directly. It read "Raw Aim Angle:
-174.0°, Corrected Aim Angle: -84.0°" (consistent with the 90°
correction: -174 + 90 = -84, confirming the math itself was working
correctly against the wrong constant) — revealing the true raw bias is
close to a full 180° inversion, not 90°. `aimCorrectionAngle` updated to
`.pi` (180°) accordingly; the next live test's debug readout will show
whether the ~6° residual (from -174° rather than exactly -180°) needs
its own follow-up tuning.

Status: Accepted

------------------------------------------------------------------------

# ADR-033 --- Cast Direction Derived From Live Rig Geometry, Not a Mesh-Tuned Constant

## Decision

`WorldViewModel.launchHook(solution:)` no longer reinterprets
`CastSolution.direction`'s `x`/`z` as a World-space horizontal launch
heading. Instead it derives the heading live, at the exact moment of
launch, from the actual rendered rig:

```text
aim = tipEntity.position(relativeTo: nil) - controllerEntity.position
horizontal = normalize(aim.x, 0, aim.z)   // falls back to (0, 0, -1) if near-zero
```

`solution.power`, `solution.launchAngle`, and `solution.distance` are
unaffected and still come from `CastSolution` as before — only the
horizontal heading component changed. `CastResolver`/`CastSnapshot`/
`CastVector3.forward` in Shared are untouched.

## Rationale

Reported directly, with a screenshot: casting with the rod visually
aimed straight out over the pier consistently landed the hook off to the
side, near the shoreline — "casting nya masih ke kanan kiri dari pier."
Root cause: `CastResolver.resolve(_:)` computes `direction` by rotating
a hardcoded `CastVector3.forward = (0, 0, -1)` by the corrected
orientation — a constant that was only ever correct for the *old*
placeholder arrow mesh (`World/World/ContentView.swift`'s pre-asset-
integration `makeArrow()`), whose tip sat along local -Z
(`tip.position = [0, 0, -0.76]`). The asset-integration merge swapped in
`rod_main.usdz` via `RodRigController`, whose entire bone chain
(`Root/Handle/Rod_01/Rod_02/Rod_03/Tip`) rests along local **+Y**
instead (every `BoneWeight.restTranslation` in `RodRigController.
rodBones` is `[0, Y, 0]`) — a rod modeled held upright, tip up, not
tip-forward. Nobody updated the hardcoded `-Z` convention when the mesh
changed, so `solution.direction` pointed wherever local -Z ended up
after rotation — a fixed, consistent offset from wherever the rig's
actual +Y-rooted tip visually swung to. This matches the reported
pattern exactly: a *consistent* rotational drift, not per-cast noise.

Per ADR-018/019 and this bug's own architecture note, `Shared` must stay
mesh-agnostic — it has no knowledge of World's rendered rig at all, so
`CastVector3.forward` cannot be "fixed" by pointing it at whatever axis
happens to match the current mesh (that just moves the same fragility to
a different constant, and breaks again on the next rig swap). The fix
belongs in World, which is the only module that knows the rig's actual
geometry: deriving the heading from `tipEntity.position(relativeTo: nil)
- controllerEntity.position` at cast time is correct by construction — it
always matches wherever the rendered tip is actually pointing, regardless
of any particular rig's internal rest-pose axis convention, and needs no
maintenance if the rig is swapped again. `controllerEntity` (the fixed-
offset `RodRoot`, per ADR-019) itself is never moved by this — only the
hook's launch trajectory is computed from it.

Status: Accepted

------------------------------------------------------------------------

# ADR-032 --- Cast Power Weighted by Backswing Distance, Not Flick Speed Alone

## Decision

Cast power — both `RodMotionInterpreter`'s live `castPower` (the charging
meter) and, more importantly, `CastResolver.resolve(_:)`'s `CastSolution.
power` (the value that actually drives `WorldViewModel.launchHook`'s hook
velocity) — previously came from instantaneous rotation-rate magnitude
alone: a single sample of angular velocity, taken once at the exact frame
release was detected. How far back the player pulled the phone during
the backswing was never measured or used.

**`RodMotionInterpreter`** now tracks `backswingPeakDistance: Double`,
the peak of `distance(current, profile.idlePose)` (the same wrapped
pitch/roll/yaw distance metric already used for idle/cast/reel pose
classification) reached since the current cast gesture began. It resets
to `0` whenever classification freshly enters `.cast`
(`previousClassification != .cast`) and otherwise only grows
(`max(backswingPeakDistance, distances.idle)`) every frame the gesture
stays in `.cast`, so it captures the deepest point of the backswing
regardless of when it happened relative to the release.

**`CastSnapshot`** (Shared, `CastResolver.swift`) gained a
`backswingDistance: Float` field, populated from `backswingPeakDistance`
at the moment `RodMotionInterpreter` builds the release snapshot. It is
Rod-internal only — never transmitted over `NetworkMessage`, consumed
solely by `RodViewModel`'s local `castResolver.resolve(snapshot)` call.

**`CastConfig`** gained `minimumBackswingDistance`/
`maximumBackswingDistance` (radians, default `0.12`/`1.0`), the
normalization bounds for `backswingDistance`, mirroring the existing
`minimumCastVelocity`/`maximumCastVelocity` bounds for flick speed.

**Both `RodMotionInterpreter`'s live `castPower` and `CastResolver.
resolve(_:)`'s final `power`** now use the same blend:

```text
distancePower = clamp01((backswingDistance - minBackswing) / (maxBackswing - minBackswing))
flickPower    = clamp01((angularSpeed - minVelocity) / (maxVelocity - minVelocity))
power = distancePower * (0.7 + 0.3 * flickPower)
```

Backswing distance sets the base — zero backswing means zero power no
matter how fast the flick — and release-moment flick speed adds up to a
30% bonus on top. `RodMotionInterpreter`'s live meter uses a local,
uncalibrated approximation of the same shape (`rotationRateMagnitude / 5`
for the flick term, matching its pre-existing simplification) so the
on-screen charging meter tracks what the eventual release will actually
produce; `CastResolver` is the authoritative, `CastConfig`-driven
calculation that becomes the transmitted `CastSolution.power`.

## Rationale

Requested directly: "doesn't matter kalo aku narik ke belakang sejauh
apapun, dia cuma nge register ketika iphone nya aku 'flick' dengan cepat,
sementara target aku kan biar iphone nya ngitung seberapa kuat cast itu
dari jarak yang dia tempuh sampai flick" (it doesn't matter how far back
I pull, it only registers when I flick the phone fast — my goal is for
the phone to compute cast strength from the distance it traveled up to
the flick). The player also asked directly whether this was a hardware
limitation from mixing flick and reel detection on one device; it isn't
— casting and reeling are already disambiguated by proximity to separate
calibrated poses (`profile.castPose`/`profile.reelPose`) before rotation
rate is ever read, and CoreMotion already provides continuous orientation
suitable for measuring displacement across a gesture, not just an
instantaneous sample at release. The actual gap was a design/logic one:
`castPower`'s only input was `rotationRateMagnitude`, sampled once at the
release frame, and `CastResolver.resolve(_:)` — the function that
produces the `CastSolution.power` actually consumed by `WorldViewModel.
launchHook`, entirely separate from `RodMotionInterpreter`'s own
`castPower` field — made the identical mistake with `snapshot.
angularVelocity.length`. Fixing only the live meter (`RodMotionInterpreter`)
would have made the on-screen number feel right while leaving actual hook
physics governed by flick speed alone; both had to change together.
A multiplicative blend (distance as the gate, flick as a bonus) was
chosen over a flat average so a good, deliberate pull-back reliably
produces a real cast regardless of how the release itself was flicked,
mirroring how a real rod loads on the backswing and releases on the
forward snap — closer to the player's own framing of the goal than a
pure distance-only formula would have been, while still rewarding a
crisp release.

This is a first pass explicitly requested to "see how it feels" — the
`0.12`/`1.0` backswing-distance bounds and the `0.7`/`0.3` blend weights
are hand-picked, not calibrated per-player or measured on-device, and are
expected to need retuning once played.

Status: Accepted

------------------------------------------------------------------------

# ADR-031 --- Cast Distance, Fight Distance, and Search-Phase Reel State Fixes

## Decision

Four related fixes to the cast/bite pipeline:

**Real measured cast distance.** `WorldViewModel` now tracks
`castLaunchPosition` (the hook's tip position at `launchHook(solution:)`)
and, when the hook splashes in `simulateFlyingHook(deltaTime:)`, computes
the horizontal distance actually traveled
(`simd_distance` between launch and splash `xz` position) and passes it to
`FishFightController.resetForNewCast(castDistance:)` — replacing the
previous no-argument call. This is the *actual* physics-simulated
distance, not `CastSolution.distance` (Rod's meter-config estimate shown
during charging, still unwired to launch physics and left as-is for that
preview use). `FishFightController` publishes it back as
`lastCastDistance: Float`, shown in `ContentView`'s Controller State grid
as "Last Cast Distance."

**Cast distance caps rollable fish size.** `FishFightController` gained
`sizeCeilingRatio: Float` (`0.3 + 0.7 * clamp01(currentCastDistance /
maxExpectedCastDistance)`, `maxExpectedCastDistance = 10.0`, an estimate
from the launch physics at full charge/level release) and
`biasedRoll(in:ceilingRatio:)`, a static helper that rolls a
`FishSpeciesRange` value capped at `range.min + span * ceilingRatio`
instead of the full range. `updateSearching(deltaTime:)`'s bite branch now
rolls `currentWeight`/`currentLength` through this instead of
`FishSpeciesRange.randomValue()`'s uniform roll. A short cast can still
land a small-to-modest fish (the 0.3 floor); only a cast near
`maxExpectedCastDistance` can roll near the species' max. Because
`sizeRatio`/`resistance` (ADR-030) already derive from
`currentWeight`/`currentLength`, a far cast landing a big fish is
automatically also a tougher fight — no separate wiring needed.

**Guaranteed minimum fight distance on bite.** `FishFightController`
gained `minimumFightDistance: Float = 0.4` (hook-to-rod meters).
`WorldViewModel.ensureFightDistance()`, called right after
`setHookPhase(.fishOnHook)` in the `.bite` branch of `tick()`'s
`.hookInWater` case, pushes the hook entity outward along the existing
rod-to-hook axis to at least this distance if it's already closer.

**Search-phase reeling no longer fakes a hooked fish.** `reelHook
(deltaTime:)`'s unconditional trailing `setHookPhase(.reeling)` is now
`if fishFight.hasFishOnHook { setHookPhase(.reeling) }`. Reeling in
during `.hookInWater` before any bite now moves the hook and, if it
reaches the rod, resolves the existing empty-retrieve path
(`hookEntity.isEnabled = false`, `setHookPhase(.idle)`) — but no longer
sets `hookPhase` to `.reeling` along the way, so `hookPhase` stays
`.hookInWater` for the entire retrieve unless a fish actually bites.

## Rationale

**Distance gating fish size** was requested directly: "semakin jauh
casting, harusnya semakin gede ikan yang bisa ditangkap. juga, distance
belum ke reflect" (the farther you cast, the bigger the fish that should
be catchable; also, distance isn't reflected anywhere yet). Two problems
existed together: `CastSolution.distance` (the value Rod's cast meter
computes and displays) was never actually consumed by
`launchHook(solution:)` — hook speed came from `power` alone — so no
"distance" concept was wired to anything, gameplay or otherwise; and fish
weight/length rolled uniformly across each species' full range regardless
of how the cast that hooked it went. Measuring the real simulated flight
distance (rather than trying to retrofit the disconnected meter estimate)
and using it to cap the roll ceiling fixes both: a value now exists,
is shown, and has a gameplay consequence.

**The minimum fight distance** fixes a reported bug: "ketika hook inwater
tapi udah aku reel duluan, ketika fishonhook, meteran line tension ga
muncul" (when the hook is in water but I already started reeling first,
the tension meter doesn't appear once it becomes fishOnHook). Root cause:
`tick()`'s `.hookInWater` case still calls `reelHook(deltaTime:)` in the
same tick a bite just occurred (the `switch hookPhase` at the top of
`tick()` captured `.hookInWater` before `setHookPhase(.fishOnHook)` ran,
so the case body keeps executing). If the player had already been
reeling in during the search phase, the hook could already be within
`reelHook`'s catch-distance threshold (`0.12`) the instant the bite
landed — `reelHook` would then resolve the catch in that same tick,
flipping `fishFight.hasFishOnHook` `true` then `false` before SwiftUI
ever rendered a frame with it `true`. `LineTensionView` is gated on
`hasFishOnHook`, so it never appeared. Pushing the hook back out to a
guaranteed minimum distance the instant a bite lands (mirroring
`initialTension`'s existing "buffer" idea from ADR-028) guarantees a real,
visible fight instead of an instant, invisible catch.

**Search-phase reeling** fixes a second, related bug reported right after
the fight-distance fix above: "ketika hook InWater terus langsung aku
reel, status nya berubah ke fishInHook, seharusnya engga kan. Kalo
reflect mancing dunia nyata, kita bisa reel sampai batas tertentu sebelum
hook nya diangkat dari air" (when the hook is InWater and I immediately
reel, the status changes to fishOnHook — it shouldn't. To reflect real
fishing, we should be able to reel up to a point before the hook is
lifted from the water). Root cause: `reelHook(deltaTime:)` set
`hookPhase` to `.reeling` on every step that moved the hook, with no
check for whether a fish was actually attached — so reeling during
`.hookInWater` (an intentional, pre-existing "empty retrieve" action)
left `hookPhase == .reeling` the moment the player stopped reeling.
`tick()`'s `case .fishOnHook, .reeling:` branch assumes reaching it means
a fish is hooked, and its not-reeling `else` branch unconditionally calls
`setHookPhase(.fishOnHook)` — so the very next tick after releasing the
reel gesture (with no bite ever having happened) flipped `hookPhase` to
`.fishOnHook`. Gating the `.reeling` transition on `hasFishOnHook`
restores that invariant: `.reeling`/`.fishOnHook` are now only ever
reached with a real fish attached, and reeling in an empty line behaves
exactly like the real-world retrieve the player described — the hook
approaches the rod and, once close enough, comes out of the water
(`.idle`), with no phase change in between. As a side effect this also
fixes a related haptic glitch: `RodViewModel.handle(_:)` stops the fish-
interested haptic pulse whenever `hookPhase != .hookInWater`, so the
same bug was prematurely killing that pulse the instant a player reeled
during search, even if no bite had happened yet.

Status: Accepted

------------------------------------------------------------------------

# ADR-030 --- Resistance Scales With Rolled Size, Not Just Species

## Decision

`FishSpecies.resistance` is now a per-species *ceiling*, not the value
used directly in the fight. `FishFightController` computes a private
`sizeRatio: Float` (0...1) from where this catch's rolled
`currentWeight * currentLength` falls between the species' min and max
weight*length product:

```text
minProduct = species.weightRange.min * species.lengthRange.min
maxProduct = species.weightRange.max * species.lengthRange.max
sizeRatio = clamp01((currentWeight * currentLength - minProduct)
                     / (maxProduct - minProduct))

resistance = species.resistance * sizeRatio
```

`resistance` still feeds `effectiveFishPullRate` and `fishPullSpeed`
exactly as ADR-026/028 defined; only how `resistance` itself is derived
changed. `FishSpecies.resistance` and `FishCatalog` are unaffected — no
data model or catalog change was needed, since this is purely a
fight-controller computation over the already-existing weight/length
ranges.

## Rationale

Requested directly: two different rolls of the same species (a puny
`Fish A` and a near-max `Fish A`) fought identically, because
`resistance` read `currentSpecies?.resistance` straight off the species
regardless of which weight/length this particular catch happened to roll
— "tension belom corespond dengan fish weight ... seharusnya, semakin
fish weight * length mendekati angka max, maka nilai resistance juga
mengikuti" (tension doesn't yet correspond to fish weight — as the fish's
weight*length approaches the max, resistance should follow). Scaling by
`sizeRatio` makes big individual catches within a species meaningfully
harder to land than small ones of the same species, matching the
weight/length roll players already see reflected in the result screen's
star rating (`FishFightController.stars(forWeight:in:)`), which used the
same weight-proximity idea for scoring but never fed it back into the
fight itself.

Status: Accepted

------------------------------------------------------------------------

# ADR-029 --- Result Screen, Rod's Minimal V1 Interface, Fish Interest

## Decision

This sprint closes three of the gaps identified against
`GAMEPLAY_ARCHITECTURE_V1.md`: no result screen, Rod still showing its full
debug UI as the primary experience, and no "Fish Interested" phase before
a bite. All three are additive to the existing `HookPhase`/
`FishFightController`/`FishingEvent` contracts from ADR-023/026/028; none
of those contracts changed shape, only grew one case each.

### Result Screen

`HookPhase` gains `.result`: entered only when `reelHook()` closes the
distance to the rod with a fish attached (`resolveCatch()`), instead of
going straight to `.idle`. `.result` is deliberately excluded from both
`allowsCasting` and `allowsReeling`, so a physical cast gesture cannot race
the result screen off the rod display before the player has seen it — this
is why the state has to live in `HookPhase` (shared, network-synced)
rather than as World-local UI state. `WorldViewModel.continueFishing()` is
the only way out, called by World's new `ResultView` "Continue Fishing"
button; it guards `hookPhase == .result` and returns to `.idle`.

Escape and line-break do **not** enter `.result` — they keep their prior
direct transitions (`.hookInWater` / `.idle`) from ADR-028. This is a
deliberate, narrower reading of `GAMEPLAY_ARCHITECTURE_V1.md`'s "Catch or
Escape -> Result" loop diagram: the doc's detailed result content (name,
weight, length, stars, coins, new-record) is explicitly scoped to "After a
successful catch" in prose, and gating every escape/line-break behind a
modal the player must dismiss would make repeated near-misses tedious in a
loop that currently has no cooldown between bites. The existing inline
"Catch Results" HUD row already surfaces escape/line-break outcomes
without blocking play.

`FishCatchResult` gains `stars: Int`, `coins: Int`, `isNewRecord: Bool`
(all `0`/`false` for non-`.caught` outcomes), computed in
`FishFightController.resolve(outcome:)` only when `outcome == .caught`:

```text
stars = 1 + round(4 * (weight - species.weightRange.min) / species.weightRange.span)   // 1...5
coins = round(species.value * (0.6 + 0.1 * stars))
```

New `World/World/Gameplay/FishRecordStore.swift` persists the heaviest
catch per species ID to `UserDefaults` (`[String: Double]`, JSON-encoded —
same pattern as `RodViewModel`'s `MotionProfile` persistence).
`recordCatch(speciesID:weight:)` returns whether this catch beat the
stored best, which becomes `isNewRecord`. New `World/World/Views/
ResultView.swift` renders the card (species, weight, length, star row,
coins, optional "NEW RECORD" badge, "Continue Fishing" button) as a
full-screen overlay in `ContentView` when `hookPhase == .result`.
"Return to Menu" from the doc's copy is intentionally not implemented —
there is no Main Menu yet to return to, and a non-functional button would
be worse than an absent one.

### Rod's Minimal V1 Interface

`Rod/Rod/ContentView.swift` is rewritten so the primary view matches
`GAMEPLAY_ARCHITECTURE_V1.md`'s Rod interface exactly: title, connection
status, and three buttons (`Start Fishing`, the existing per-step
calibration button relabeled inline, `End Fishing`). All prior debug rows
(connection/spatial/motion status, calibration step/sample count, raw
pitch/roll/yaw/action/reelSpeed/etc.) move into a `DisclosureGroup`
labeled "Developer Details", collapsed by default, instead of being
deleted — matching this repo's existing precedent of keeping development
tooling available but demoted (e.g. the commented-out `MotionDebugView`
section) rather than removing it.

`RodViewModel` gains `isFishing: Bool` (`@Published private(set)`) and
`startFishing()`/`endFishing()`. `startFishing()` only takes effect once
`calibrationStep == .complete`. `updateAction()`'s existing
`hookPhase.allowsCasting`/`allowsReeling` gate gains a third condition
ahead of both: `!isFishing` forces `action = .idle` regardless of motion.
Before this, cast/reel gestures were always live the moment calibration
finished; now the player must explicitly start (and can explicitly end) a
session, giving the doc's three buttons real functional meaning rather
than only "Calibrate" doing anything.

**Known gap, not addressed this sprint:** `GAMEPLAY_ARCHITECTURE_V1.md`
also states "Calibration instructions appear entirely in World. Rod only
captures..." Rod's `calibrationInstruction` text (unchanged from before
this sprint) still lives on Rod, not World. This is pre-existing, not
introduced here, and is tracked as part of the still-open "World Main
Menu + Tutorial + Calibration instructions" gap.

### Fish Interested

`GAMEPLAY_ARCHITECTURE_V1.md`: "A nearby fish becomes interested but has
not bitten. World shows subtle movement and Rod provides slow periodic
vibration." This does not need its own `HookPhase` — reeling is already
allowed throughout `.hookInWater` regardless of interest, so it is
presentation-only state inside the existing search phase.

`FishFightController.updateSearching(deltaTime:)` now returns
`SearchEvent? { .interested, .bite }` instead of `Bool`, driven by two
sequential timers instead of one: `interestTimer` (`0.8...2.0s`) then,
once interested, `biteTimer` (`0.8...2.0s`) — replacing the single
`1.5...4.0s` `biteTimer` from ADR-023, so total time-to-bite stays in
roughly the same range. `isFishInterested: Bool` (`@Published`) is exposed
for a future World visual cue (not added this sprint — fish still have no
visual representation). `FishingEvent` gains `.fishInterested`, sent once
by `WorldViewModel` when `updateSearching` returns `.interested`.

Rod's periodic vibration is a new pattern:
`FishingHaptics.interestPulse(now:)` (throttled to `1.1s`, mirroring
`reelTick(reelSpeed:now:)`'s existing throttle idiom) is a no-op unless an
internal `isFishInterested` flag is set, which `handle(.fishInterested)`
sets and every other `FishingEvent` case (plus
`RodViewModel.handle(.hookPhase:)` whenever the phase leaves
`.hookInWater`, via the new `stopInterest()`) clears — so a stale interest
signal can't keep pulsing after the fish bites, escapes, or a new cast
begins. `RodViewModel.updateAction()` calls `interestPulse()`
unconditionally every motion sample, the same recurring callback that
already drives `reelTick`. `HapticManager.fishInterested()` is a single
soft transient (`0.22`/`0.15`), deliberately duller than `fishBite()`'s
four-pulse pattern.

## Rationale

Each of these three gaps was explicitly named as missing against the
product doc in the prior gap analysis; developing them together was
requested directly ("develop points 1-3 this sprint"). They compose
without touching each other's mechanics: the result screen only changes
what happens after a catch resolves, the Rod UI change only changes
whether a resolved motion action is allowed to leave the device, and fish
interest only changes what happens before a bite — none required changing
the tension/fight simulation from ADR-028.

Status: Accepted

------------------------------------------------------------------------

# ADR-028 --- Unified Tension Safe Zone Replaces the Duration Timer

## Decision

ADR-027's duration-only tension formula is replaced, one task later, by the
single tension-with-safe-zone mechanic `GAMEPLAY_ARCHITECTURE_V1.md`
already specified: "the player keeps tension in a safe zone... sustained
tension too high or too low causes the fish to escape." Two problems
prompted this: `lineTension` froze while the player wasn't reeling instead
of reflecting anything happening in the fight, and the *separate*
`biteExpireTimer`/`updateWaiting` mechanic (ADR-024) that actually caused
escapes was a flat countdown fully disconnected from hook/rod distance —
contradicting the player's (correct) expectation that a hooked fish should
visibly fight by pulling the hook away.

`FishFightController` now has one continuous update path,
`updateFight(deltaTime:isReeling:reelSpeed:)`, called every tick while
`hasFishOnHook` (both `.fishOnHook` and `.reeling` `HookPhase`s):

```text
reelPull = isReeling ? reelSpeed * baseReelTensionRate(0.5) : 0
lineTension += (reelPull - effectiveFishPullRate) * deltaTime
effectiveFishPullRate = baseFishPullRate(0.15) * (1 + resistance)

lineTension <= 0  -> FightFailure.escaped   (line went slack)
lineTension >= 1  -> FightFailure.lineBreak (reeled too hard)
```

A bite starts `lineTension` at `initialTension` (0.5), not 0, giving the
player room to react in either direction. `updateWaiting`, `pauseFight`,
`biteExpireTimer`, `baseBiteExpireDuration`, and ADR-027's
`updateFighting(deltaTime:)`/`baseMaxFightDuration` are all removed —
tension alone now governs both failure modes.

**The fish now physically pulls the hook.** `FishFightController` exposes
`fishPullSpeed: Float` (m/s, species-scaled, zero when no fish is hooked)
so `WorldViewModel` can move the hook entity itself — `FishFightController`
still has no RealityKit/entity knowledge, it only publishes a speed.
`WorldViewModel.driftHookAway(deltaTime:)` moves the hook away from the rod
along the existing rod-to-hook axis (the same vector `reelHook(deltaTime:)`
already used, just reversed) whenever a fish is hooked and the player isn't
reeling. Reeling still moves the hook toward the rod via the existing
`reelHook(deltaTime:)`/distance-to-catch logic, unchanged. The result is an
actual tug-of-war: not reeling lets the fish visibly drag the hook away
(and drains tension); reeling pulls it back (and, if sustained too hard,
raises tension toward a snap).

`WorldViewModel.tick(deltaTime:)` merges the `.fishOnHook` and `.reeling`
`HookPhase` switch cases into one block, since both now run the same
reel-or-drift-plus-tension-update logic and differ only in which the
player is currently doing. `resolveFightFailure(_:)` reacts to
`FishFightController.FightFailure` (`.escaped` -> `HookPhase.hookInWater`,
keep fishing; `.lineBreak` -> hook disabled, `HookPhase.idle`, recast
required), mirroring the event-sending shape `reelHook`'s catch path
already had.

`LineTensionView` now shades a visible safe zone (`0.3...0.7`) on the bar
and shows a `"LOSING FISH"` warning below `0.15` alongside the existing
`"SNAPPING"` above `0.85`, instead of a single-direction green-to-red ramp
that only made sense for a one-way failure mode.

## Rationale

Requested directly after the player noticed the tension bar never reset
while idle and the fish escaped on a flat ~2.5s timer with no connection to
the hook visibly getting away — "setau aku ikan nya bisa ngelawan dengan
ngejauhin lagi distance si hook nya relatif ke rod" (as far as I know the
fish should be able to fight back by pulling the hook's distance from the
rod farther away). Re-reading `GAMEPLAY_ARCHITECTURE_V1.md`'s own line
tension description confirmed the safe-zone design was the intended V1
mechanic all along; ADR-023/024/026/027 had incrementally built two
separate, simpler mechanisms (a flat escape timer, then a one-directional
duration-based snap timer) instead. Collapsing them into the one
mechanism the product doc already specifies removes both problems at once
and gives the fish a real, visible presence in the fight rather than an
invisible clock.

Status: Accepted

------------------------------------------------------------------------

# ADR-027 --- Line Tension Tracks Fight Duration, Not Reel Speed

## Decision

`FishFightController.updateFighting(deltaTime:)` no longer takes a
`reelSpeed` parameter or compares it to a per-species safe threshold.
`lineTension` now accumulates purely from elapsed time spent actively
reeling a hooked fish:

```text
lineTension += deltaTime / effectiveMaxFightDuration
effectiveMaxFightDuration = max(2.0, baseMaxFightDuration(6.0) * (1 - resistance * 0.5))
```

Tension only advances while `WorldViewModel` is calling `updateFighting`,
i.e. while `HookPhase == .reeling` and the player is actively reeling; it
is untouched (frozen, not decayed) whenever reeling pauses, since the call
site simply stops calling it (`pauseFight()` still resets the separate
`biteExpireTimer` for the escape clock). There is no decay branch anymore.
The three former constants (`baseSafeReelSpeed`, `baseTensionRiseRate`,
`tensionDecayRate`) and their `effective*` computed properties were
removed; `effectiveMaxFightDuration` is the only new one, still scaled by
species `resistance` (stronger fish give less total fight time before the
line snaps).

This amends ADR-026's tension formula only. ADR-026's `FishSpecies`/
`FishCatalog` data model, the `FishFightController` extraction, and the
HUD (`LineTensionView`, catch results) are all unaffected — `lineTension`
is still a `@Published 0...1 Float` and `WorldViewModel`'s call site
still reacts to `updateFighting`'s bool return the same way.

## Rationale

Requested directly: the meter should reflect how long the player has been
reeling, not how fast — "kalo user kelamaan nge reel, otomatis reel
meternya bisa max dan line putus" (if the player reels for too long, the
meter maxes out on its own and the line breaks). A duration budget per
fight is simpler to read from the bar (it always climbs while you're
reeling, so the bar's rate of climb answers "how much time do I have
left") and simpler to reason about than a speed-conditioned accumulate/
decay rule, while still giving stronger fish a shorter, harder fight via
the same `resistance` modifier introduced in ADR-026.

Status: Superseded by ADR-028, one task later — the duration-only formula
this ADR introduced didn't address the player's actual request (a real
safe-zone mechanic where the fish fights back via hook distance), so it
was replaced rather than further amended. Left below for history.

------------------------------------------------------------------------

# ADR-026 --- FishSpecies Data Model and Continuous Line Tension

## Decision

Two related changes replace ADR-024's binary line-break timer with a real
tension meter and separate fish data from fight logic:

**`FishSpecies` (Shared).** Added
`Shared/Sources/Shared/Models/FishSpecies.swift`: a `Codable` data-only
struct (`id`, `name`, `weightRange`, `lengthRange`, `resistance` 0...1,
`value`) plus `FishSpeciesRange` (a `Codable` replacement for `ClosedRange`,
which does not synthesize `Codable`). It carries no mesh, asset name, or
RealityKit reference — Shared still never imports rendering frameworks. The
World-owned content list (`World/World/Gameplay/FishCatalog.swift`, one
entry today: `"fish_a"`) is where species are defined and tuned; asset
wiring is deferred until 3D fish assets exist.

**Continuous line tension.** `FishFightController` (new,
`World/World/Gameplay/FishFightController.swift`, an `ObservableObject`)
replaces the boolean `lineStrainTimer`/threshold/sustain-duration mechanic
with a `lineTension: Float` (0...1) that rises while reeling above a
per-species "safe" reel speed and decays otherwise, breaking the line at
1.0. `biteTimer`/`hasFishOnHook`/`biteExpireTimer`/catch bookkeeping also
moved out of `WorldViewModel` into this controller, which
`WorldViewModel.tick(deltaTime:)` now drives through a small explicit
interface (`updateSearching`, `updateWaiting`, `pauseFight`,
`updateFighting`, `resolveCatch`, `resetForNewCast`); `WorldViewModel`
still owns `HookPhase` transitions and sending `FishingEvent` over
transport, since fight state itself has no transport or hook-entity
knowledge. `WorldViewModel` also gained `caughtCount` and
`lastCatchResult: FishCatchResult?` (`World/World/Gameplay/
FishCatchResult.swift`) for HUD display.

Species `resistance` now scales three constants: bite grace period
(`effectiveBiteExpireDuration`), the safe reel speed before tension rises
(`effectiveSafeReelSpeed`), and the tension rise rate
(`effectiveTensionRiseRate`) — a stronger fish gives less reaction time and
snaps the line faster under strain.

**World HUD additions.** `World/World/Views/LineTensionView.swift` renders
`fishFight.lineTension` as a green/yellow/red 0...1 bar, visible whenever
`fishFight.hasFishOnHook`. `ContentView` adds a "Catch Results" section
showing `fishFight.caughtCount` and the last resolved outcome (species
name, weight, length, caught/escaped/line-broke). `ContentView` now
observes `WorldViewModel.fishFight` directly as a second `@ObservedObject`
(constructed in `init()` from the same instance `WorldViewModel` owns), so
its `@Published` fight state drives the HUD independently of
`WorldViewModel`'s own `@Published` properties.

## Rationale

A binary "sustained fast reel for N seconds" rule cannot be shown to the
player as a meaningful 0...1 bar — it is just off or (after N seconds) on.
A continuously accumulating/decaying value is both a more honest fishing-
game mechanic and the only thing a tension bar can actually visualize.
Moving fish/fight state into `FishFightController` was necessary before
adding it: `WorldViewModel` was already at the file-size guideline in
`AGENTS.md` after ADR-023/024, and fish bite/escape/tension/catch
bookkeeping is a cohesive unit of behavior that does not need
`WorldViewModel`'s transport, hook-entity, or `HookPhase` internals to
operate — it only needs `deltaTime` and `reelSpeed` in, and yes/no
transition signals out. Splitting `FishSpecies` (data) from `FishCatalog`
(World-owned content) from `FishFightController` (simulation) from
`FishCatchResult` (HUD projection) keeps each piece swappable
independently — the stated reason for the split is that fish will soon get
real assets and more species, and the data model must not assume a
particular mesh or rendering approach.

Status: Accepted

------------------------------------------------------------------------

# ADR-024 --- Escape Timer and Reel-Speed Line Break

## Decision

Building on ADR-023's `fishOnHook` state, World now implements minimal line
tension without a full tension bar, using two independent timers owned by
`WorldViewModel`:

-   `biteExpireTimer` counts down while `.fishOnHook` and the player is not
    reeling. On expiry the fish escapes: `hasFishOnHook` clears,
    `HookPhase` returns to `.hookInWater` (a fresh `biteTimer` starts, so the
    hook keeps fishing rather than forcing a recast), and
    `FishingEvent.fishEscaped` sends. Pausing mid-fight resets this timer
    to `biteExpireDuration` (2.5s) rather than continuing to drain it, so a
    deliberate pause and an unaddressed bite are treated the same way.
-   `lineStrainTimer` accumulates only while actively reeling with
    `hasFishOnHook == true` and `RodState.reelSpeed` at or above
    `lineBreakReelThreshold` (0.9). Sustaining that for
    `lineBreakSustainDuration` (1.2s) snaps the line: the hook disables,
    `hasFishOnHook` clears, `HookPhase` returns to `.idle` (the line is
    gone; a new cast is required), and `FishingEvent.lineBreak` sends.
    Dropping below the threshold at any point resets the timer to zero.

`FishingEvent.fishEscaped` and `.lineBreak` were previously defined and
already handled by `Rod/Rod/Haptics/FishingHaptics.swift`, but World never
sent either one before this change. `HapticManager` gained a distinct
`fishEscaped()` pattern (a fading three-pulse taper) instead of aliasing to
the sharp single-transient `lineBreak()` pattern, so the two failure modes
feel different to the player.

## Rationale

A real tension bar (per `GAMEPLAY_ARCHITECTURE_V1.md`) needs UI, a
resistance-per-species model, and a sustained safe-zone mechanic that is out
of scope for this task. Two independent timers give the same core pressure
—react to a bite in time, then don't reel too aggressively—without any of
that. Making pausing reset the escape timer (rather than a monotonic clock
since the bite) keeps the rule simple: the fish is only lost through
inaction, never through unlucky timing across a reel/pause boundary.

Status: Superseded by ADR-028. Both timers this ADR introduced
(`biteExpireTimer` and `lineStrainTimer`) were replaced by the unified
tension safe zone — the "sustained safe-zone mechanic" explicitly called
out above as out of scope for this task turned out to be exactly what the
product doc already specified and what the player expected. Left below for
history.

------------------------------------------------------------------------

# ADR-025 --- Reel Speed Scales Continuously With Rotation Rate

## Decision

`RodMotionInterpreter`'s `.reel` classification previously computed
`reelSpeed` as
`min(1, input.rotationRateMagnitude / max(profile.reelRotationRate, 1))`.
Because `profile.reelRotationRate` (the calibrated minimum reel-detection
threshold, `max(0.2, averageRate * 0.45)`) is almost always well under 1.0,
the `max(_, 1)` floor made the denominator effectively constant at `1`, and
real device rotation rates during an actual reeling motion routinely exceed
1 rad/s. `reelSpeed` therefore saturated to `1.0` almost immediately after
crossing the detection threshold, reading as binary 0/1 rather than a
dynamic value.

`MotionProfile` gains `reelFullRotationRate`, captured during reel
calibration in `RodViewModel.calibrateMotion()` as
`max(reelRotationRate + 0.3, peakRate)`, where `peakRate` is the maximum
rotation rate magnitude observed across the player's demonstrated reel
samples (previously only the average was used). `reelSpeed` is now a linear
ramp between the two calibrated references:

```text
speed = clamp((rotationRateMagnitude - reelRotationRate)
              / (reelFullRotationRate - reelRotationRate), 0...1)
```

`reelRotationRate` remains 0 speed (the minimum motion still recognized as
reeling); `reelFullRotationRate` (the player's own demonstrated peak) is
1.0. Spinning faster than that still clamps at 1.0; spinning at the
threshold reads near 0. `MotionProfile` is Codable and persisted to
`UserDefaults`; `RodViewModel.loadMotionProfile()` already discards
undecodable stored profiles with `try?`, so profiles saved before this
change safely fall back to requiring recalibration rather than crashing.

## Rationale

The player-reported symptom was reel speed reading constant at 1.000 or
0.000 instead of tracking how fast they physically spin the controller.
The fix keeps the existing per-player calibration model (Rod owns sensing
and motion interpretation per `AGENTS.md`) but uses the player's own
demonstrated range as both ends of the scale, instead of an arbitrary
floor that happened to make the scale collapse for most real rotation
rates.

Status: Accepted

------------------------------------------------------------------------

# ADR-001 --- World/Rod Separation

## Decision

Split the application into two independent apps.

-   World (macOS)
-   Rod (iPhone)

## Rationale

The renderer and the controller have different responsibilities.

Benefits:

-   Easier testing
-   Independent deployment
-   Cleaner architecture
-   Reusable controller

Status: Accepted

------------------------------------------------------------------------

# ADR-022 --- Fish Spawn Ownership (Fish A)

## Decision

Fish spawning is a World-only concern with no Shared or Rod involvement.
`World/World/Gameplay/FishManager.swift` owns a single fish entity's spawn,
despawn, and idle swim motion. It is instantiated and driven by
`WorldViewModel`, keeping `WorldViewModel` itself under the ViewModel file
size guideline.

Fish A spawns when `HookPhase` transitions from `.flying` to `.hookInWater`
and despawns when the phase returns to `.idle`. It has no interest, bite, or
fight behavior yet; it only exists and swims in a slow idle loop near a
randomized point in the water. Fish selection, species data, resistance, and
the searching/interested/bite state machine described in
`GAMEPLAY_ARCHITECTURE_V1.md` remain unimplemented and are deferred to a
future task.

The fish body uses a non-uniformly scaled sphere primitive, matching the
existing primitive-mesh approach used for the rod arrow and hook (no capsule
mesh primitive is available on this RealityKit SDK, and no fish asset exists
yet).

## Rationale

Keeping fish spawn logic in a dedicated manager preserves `WorldViewModel`'s
role as a coordinator rather than a growing gameplay implementation, and
keeps the fish system isolated so future searching/interest/bite/fight work
can extend `FishManager` without touching hook or controller logic.

Status: Superseded by ADR-023. Direction changed the same day: no visual
fish entity for now, in favor of getting the `HookPhase` state machine
itself to reflect a real fish grab first. `FishManager.swift` was removed.

------------------------------------------------------------------------

# ADR-023 --- Hook Phase Reflects a Real Fish Grab, No Visual Fish Yet

## Decision

Before any fish is rendered in World, `HookPhase` (Shared) must accurately
represent whether a fish is actually attached to the hook, so that gameplay
state and Rod haptics are truthful rather than cosmetic. This reverses
ADR-022's visual-first approach.

`HookPhase` gains a `fishOnHook` case between `hookInWater` and `reeling`:

```text
idle -> flying -> hookInWater -> fishOnHook -> reeling -> idle
                (searching)      (bite)       (fight)   (catch)
```

`WorldViewModel` tracks the attachment as private simulation state, not as
part of `HookPhase` itself:

-   `biteTimer` counts down while `hookInWater` (searching). On expiry,
    `hasFishOnHook` becomes `true`, the phase moves to `.fishOnHook`, and
    `FishingEvent.fishBite` is sent — the first real use of that existing
    but previously unsent event.
-   Reeling is allowed from `hookInWater` (retrieve an empty hook, no event)
    or from `fishOnHook`/`reeling` (retrieve a hooked fish).
-   When the hook reaches the rod, `FishingEvent.catchFish` is sent only if
    `hasFishOnHook` was true — also a first real use of an existing,
    previously unsent event.
-   `biteTimer` and `hasFishOnHook` reset on every new splash
    (`simulateFlyingHook`), so each cast gets an independent chance to hook
    a fish.

No fish entity, mesh, or RealityKit visual exists yet. No searching/interest
distinction, line tension, or escape logic exists yet — a bite always
succeeds if reeled in. Those remain future work per
`GAMEPLAY_ARCHITECTURE_V1.md`.

## Rationale

The gameplay loop and Rod haptics (`FishingHaptics.handle(_:)` already
switches on every `FishingEvent` case, including `fishBite` and
`catchFish`) were built against events that World never actually sent.
Rendering a fish in the scene before the underlying state machine reflects
a real bite/catch would make the visual a lie layered on top of a
non-functional loop. Fixing `HookPhase`/`FishingEvent` truthfulness first
means any future visual or haptic work has a correct state machine to
attach to.

Status: Accepted

------------------------------------------------------------------------

# ADR-020 --- Rod as Controller, World as Game

## Decision

Catch the Scott is a two-device experience with a strict product boundary:
Rod is a physical input device and World is the complete game. World owns
menus, tutorials, calibration instructions, HUD, hook/fish simulation,
results, and progression. Rod owns motion, calibration capture, cast/reel
intent, buttons, connection status, and haptic output.

No gameplay information may be rendered on Rod in V1. World is the sole owner
of gameplay state and player-facing feedback. Rod receives only the input
commands and typed feedback events required to operate the physical
controller.

## Rationale

Keeping the iPhone visually quiet preserves the intended illusion that the
player is holding a fishing rod rather than using a second game screen. It
also prevents gameplay rules, fish state, and presentation logic from being
duplicated across devices.

Status: Accepted

------------------------------------------------------------------------

# ADR-017 --- Cast Resolver Boundary

## Decision

Cast motion is captured once as an immutable `CastSnapshot` containing the
corrected orientation, angular velocity vector, and timestamp. `CastResolver`
converts that snapshot into a `CastSolution` containing normalized power,
horizontal direction, and launch angle.

The motion interpreter detects the release but does not perform gameplay
balancing. World/gameplay consumes the solution and never reads CoreMotion.

## Rationale

Separating motion interpretation from gameplay translation allows cast power,
distance, arc, VFX, audio, and haptics to be balanced without changing the
controller sensor pipeline.

Status: Accepted

------------------------------------------------------------------------

# ADR-002 --- Shared Swift Package

## Decision

All shared models and protocols live inside the Shared Swift Package.

## Rationale

Avoid code duplication.

World and Rod communicate using identical models.

Status: Accepted

------------------------------------------------------------------------

# ADR-003 --- RodState is the Single Source of Truth

## Decision

All controller information is represented by one model.

``` swift
RodState
```

Gameplay and rendering consume RodState only.

No duplicate motion state may exist.

Status: Accepted

------------------------------------------------------------------------

# ADR-004 --- Separation of Motion and Spatial Data

## Decision

CoreMotion and Nearby Interaction remain independent.

Motion:

-   Pitch
-   Roll
-   Yaw

Spatial:

-   Distance
-   Direction

RodState combines both domains.

Status: Accepted

------------------------------------------------------------------------

# ADR-005 --- RealityKit Exists Only in World

## Decision

RealityKit rendering belongs exclusively to World.

Rod never renders the simulation.

## Rationale

Rod is a physical controller.

Status: Accepted

------------------------------------------------------------------------

# ADR-006 --- Rod Never Depends on Reality

Rod must never import:

-   RealityKit
-   ARKit

Its responsibility is sensing and input.

Status: Accepted

------------------------------------------------------------------------

# ADR-007 --- Shared Must Be Platform Independent

Shared may import:

-   Foundation

Shared must not import:

-   SwiftUI
-   RealityKit
-   CoreMotion
-   NearbyInteraction
-   CoreHaptics
-   UIKit
-   AppKit

Status: Accepted

------------------------------------------------------------------------

# ADR-008 --- MVVM

Use MVVM throughout the project.

Views remain passive.

Business logic belongs in ViewModels and Managers.

Status: Accepted

------------------------------------------------------------------------

# ADR-009 --- Composition Over Inheritance

Prefer composition and protocols.

Avoid deep inheritance hierarchies.

Status: Accepted

------------------------------------------------------------------------

# ADR-010 --- Incremental Delivery

Implementation proceeds sprint-by-sprint.

Each sprint must:

-   Build
-   Run
-   Be testable

No sprint may depend on unfinished work.

Status: Accepted

------------------------------------------------------------------------

# ADR-011 --- Gameplay Deferred

Fishing mechanics are intentionally postponed.

Priority:

1.  Spatial session
2.  Motion
3.  Synchronization
4.  Reality visualization
5.  Gesture recognition
6.  Gameplay

Status: Accepted

------------------------------------------------------------------------

# ADR-012 --- Apple-First APIs

Use the latest stable Apple SDKs.

Prefer:

-   Nearby Interaction
-   RealityKit
-   CoreMotion
-   CoreHaptics
-   Swift Concurrency

Avoid deprecated APIs in new implementations.

Status: Accepted

------------------------------------------------------------------------

# ADR-013 --- Loose Coupling

World and Rod communicate only through shared contracts.

------------------------------------------------------------------------

# ADR-014 --- Nearby Interaction Ownership

## Decision

Rod owns the Nearby Interaction session. World receives the resulting spatial
state through `RodState` over the shared transport contract.

## Rationale

The current macOS SDK marks `NISession` and its peer configuration APIs as
unavailable on macOS. Keeping the NI implementation on Rod preserves the
physical-controller model while allowing World to run as a native macOS app.

No project may import the other project.

Status: Accepted. Ownership as described here is still correct — Rod still runs the session
exactly this way. See ADR-041: the resulting spatial state is not currently read by any gameplay
or rendering code, only by debug display; this ADR's ownership rule is unaffected either way.

------------------------------------------------------------------------

# ADR-021 --- Debug First

Every subsystem should expose observable debug information before
gameplay is implemented.

Examples:

-   Session state
-   Distance
-   Direction
-   Pitch
-   Roll
-   Yaw
-   Update frequency

Status: Accepted

------------------------------------------------------------------------

# ADR-015 --- Reusable Spatial Controller

The long-term objective is not a fishing game.

The objective is a reusable spatial controller framework capable of
supporting multiple interaction paradigms such as:

-   Fishing rod
-   Tennis racket
-   Baseball bat
-   Golf club
-   Sword
-   Other spatial interaction experiences

Fishing is the first consumer of the framework.

Status: Accepted

------------------------------------------------------------------------

# Change Policy

Any modification to these decisions should:

1.  Explain why the existing decision is insufficient.
2.  Describe the proposed alternative.
3.  Document trade-offs.
4.  Be approved before implementation.

Architectural consistency takes priority over short-term implementation
convenience.

------------------------------------------------------------------------

# ADR-019 --- Controller Root and Hook Simulation Separation

## Decision

World keeps `RodRoot` at a fixed camera-relative offset and applies only
`RodState.orientation` to its orientation. Cast direction, power, and distance
are consumed exclusively by hook launch and simulation. Reeling updates the
hook position and never repositions the rod root.

## Rationale

The controller is the player's hand representation, while the hook is the
gameplay projectile. Coupling the rod root to cast distance caused the rod to
move forward during casting and snap back after reeling. Separate entity
ownership keeps the controller attached to the player and makes future fishing
line rendering independent of controller movement.

Status: Accepted

------------------------------------------------------------------------

# ADR-018 --- Gesture Charging and Transform Separation

## Decision

The Rod/Shared motion layer owns gesture phases (`Idle`, `Backswing`,
`Charging`, `Forward Swing`, `Release`, and `Follow Through`) and publishes
live normalized `castPower` in `RodState`. A release is resolved once into a
persistent `CastSolution`; World consumes that solution for hook physics and
HUD presentation.

Rod spatial state and cast gameplay state are separate contracts. Nearby
Interaction distance/direction control the rod root. Cast direction, power,
and distance control only the hook trajectory and cast HUD. World must not
reconstruct cast values from raw motion or use cast distance to move the rod.

## Rationale

Mixing cast output into the rod transform made the controller visibly translate
when a cast was released. Keeping the rod root spatial and the hook dynamic
preserves stable controller rendering while allowing the cast to travel.

Status: Accepted

------------------------------------------------------------------------

# ADR-016 --- Calibration-Owned Orientation

## Decision

Calibration belongs to the Rod/Shared motion pipeline. The calibration layer
captures and persists an Idle reference quaternion, applies its inverse to each
current device orientation, and publishes the corrected orientation in
`RodState.orientation`.

World consumes that orientation as-is. World does not know whether a
calibration reference exists and does not apply offsets or reconstruct the
calibrated orientation from Euler angles.

Gameplay-relative pose may be derived separately from corrected motion, but it
must not become the renderer's orientation source.

## Rationale

Using relative Euler values for both gameplay and rendering caused the rod to
appear to snap when calibration ended. A normalized quaternion contract keeps
the visual pipeline stable and makes the ownership boundary explicit.

Status: Accepted

------------------------------------------------------------------------

# ADR-030 --- World Explicitly Authors the First-Person Camera

## Decision

`RealityView` in non-AR ("virtual") mode has no ARKit device camera to fall
back on and provides no default first-person viewpoint of its own. World
must always create and add an explicit `PerspectiveCamera` entity to the
scene, and set `content.camera = .virtual` in the `RealityView` closure.

## Rationale

Without an explicit camera entity, RealityKit auto-frames the scene's
bounding box from an arbitrary vantage point instead of the intended
first-person view. This previously shipped as a bug: the player appeared to
stand underwater looking up at the dock's underside.

The camera's position/orientation must be derived from the asset repo's own
authored viewpoint (the Blender `player_pov` camera), converted through the
verified Blender-Z-up-to-RealityKit-Y-up axis mapping
(`(x, y, z) -> (x, z, -y)`), not guessed. See `CHECKPOINT.md` ("Asset-
Integration Environment, First-Person Camera, and Rod Motion Fixes") for the
empirical derivation.

Status: Accepted

------------------------------------------------------------------------

# ADR-031 --- Transport Delivery Mode Matches Message Freshness, Not a Blanket Default

## Decision

`NetworkMessage` declares `requiresReliableDelivery` per case. Continuous,
high-frequency telemetry (`state`, the streamed `RodState`) sends unreliable:
a stale sample is worthless once superseded, so retransmitting a dropped one
only adds latency for every real sample queued behind it. Discrete, one-shot
signals (`discoveryToken`, `fishingEvent`, `hookPhase`) stay reliable, since
losing one of those silently breaks game state rather than just aging out.
Both `TransportHost` and `TransportClient` read this flag to pick
`MCSessionSendDataMode` instead of hardcoding `.reliable` for every send.

## Rationale

MultipeerConnectivity's `.reliable` mode is TCP-like: ordered and
retransmitted. Sending the entire live motion stream this way meant any
single dropped packet under real Wi-Fi/Bluetooth conditions caused
head-of-line blocking — every subsequent, already-stale sample queued behind
the retransmit — which read directly as controller/rod lag independent of
frame rate or rendering. See `CHECKPOINT.md` ("Controller lag fix, FPS debug
indicator, and a stuck-error/casting investigation") for the full
investigation and the two other contributing causes found alongside this one.

Status: Accepted
