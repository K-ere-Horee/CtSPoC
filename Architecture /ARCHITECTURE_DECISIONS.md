# ARCHITECTURE_DECISIONS.md

# CtS PoC - Architecture Decision Record (ADR)

Version: 1.0

This document records architectural decisions that are considered stable
for the Catch the Scott Spatial Controller PoC. Future changes should
preserve these decisions unless there is a compelling technical reason
to revise them.

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

Status: Accepted

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
