# WINDOW_1.md — Session Handoff

Written because the context window this work happened in was about to run out.
This is a **navigation summary**, not a replacement for `CHECKPOINT.md` (the
full, permanent, entry-per-task history) or `ARCHITECTURE_DECISIONS.md` (the
full ADR text) — both already have complete detail for everything below. This
file exists so the next window can get oriented in one read instead of
re-deriving context from the full logs.

Covers **ADR-030 through ADR-039**. Everything referenced here is already
**committed and pushed** to `origin/dev` — `git log --oneline -8` from the end
of this window:

```text
819e1f6 chore: tune some settings under fish fight
7236d0b feat(gameplay): harder it is to catch fish since base speed on reel and fish escape has been tuned.
32a4d4c feat: add main menu, fish progression, and rod-driven session control
234e4b0 feat: replace MultipeerConnectivity transport with CoreBluetooth
b1fddcc feat: add cast direction debug to cleanup casting mechanism (it's fixed now at least)
bd3baf8 chore: set a commit position before updating even further
163e5f4 docs: record the feat/asset-integration merge in CHECKPOINT.md
2fc7ab0 Merge remote-tracking branch 'refs/remotes/origin/feat/asset-integration'
```

Working tree was clean at the end of this window (only the usual
`.xcuserstate` IDE-state noise).

------------------------------------------------------------------------

## TL;DR — what actually changed this window

Six areas of work, roughly in order:

1. **Fish fight tuning** (ADR-030): species `resistance` scales with how big a
   catch actually rolled, not a flat per-species value.
2. **Cast distance + fight distance fixes** (ADR-031): real measured cast
   distance caps fish size, guaranteed minimum fight distance on bite, and a
   search-phase-reeling state bug fixed.
3. **Cast power from backswing distance** (ADR-032): cast power now comes from
   how far back you actually pulled, not just release-moment flick speed.
4. **Cast *direction*, fixed across several passes** (ADR-033/034): the rig's
   tip-vs-root aim vector was pointing almost exactly backward (-174°, not a
   90° quirk as first guessed); corrected via live-measured debug angle
   readouts, then hard-clamped to a 135° forward cone as a safety net.
5. **CoreBluetooth transport migration** (ADR-035): full replacement of
   MultipeerConnectivity. Rod = BLE peripheral, World = BLE central.
6. **Main Menu, progression, Rod-owned session control, fight difficulty pass**
   (ADR-036 through ADR-039): World gets a real entry screen; fish now come in
   tiers (small/medium/big/boss = Scott) unlocked by catch counts; Rod's
   Start/End Fishing button is now the sole session-boundary control instead
   of a World-side button; and the fight itself got a full difficulty/feel
   pass (tug-of-war, distance-escape, continuous tension haptics, fight
   camera) — including two live-tested corrections after the first pass
   turned out to be unplayable.

**The single most load-bearing outcome of this window**: almost none of it has
been run live. This was a long stretch of code-level implementation and
hand-worked math, verified only via `swiftc -typecheck` on macOS + iOS-simulator
targets, not via `xcodebuild`, not on a real device, and not by actually
playing the game — except for the two spots explicitly noted below where the
player did test live and reported back (cast direction, and the fight-difficulty
correction). Treat everything else as **unverified until played**.

------------------------------------------------------------------------

## Full list, in order, with pointers

Each item below has a full `ARCHITECTURE_DECISIONS.md` entry and a full
`CHECKPOINT.md` entry (search either file for the ADR number or the section
title in quotes).

| # | What | Where to read more |
|---|------|---------------------|
| ADR-030 | Resistance scales with rolled fish size, not flat per-species | `ARCHITECTURE_DECISIONS.md` |
| ADR-031 | Cast distance caps fish size; guaranteed fight distance on bite; search-phase-reeling fixed | `ARCHITECTURE_DECISIONS.md` |
| ADR-032 | Cast power from backswing distance, not just flick speed | `ARCHITECTURE_DECISIONS.md` |
| ADR-033 | Cast direction derived from live rig geometry (tip vs. root), not a mesh-tuned constant | `ARCHITECTURE_DECISIONS.md` |
| ADR-034 | Cast direction clamped to a 135° forward cone; bobber 2x size; **live-corrected**: raw aim angle measured at -174° (not ~90°), `aimCorrectionAngle` set to 180° | `ARCHITECTURE_DECISIONS.md` |
| ADR-035 | MultipeerConnectivity → CoreBluetooth, full replacement | `ARCHITECTURE_DECISIONS.md` |
| ADR-036 | World Main Menu; scene stays mounted across menu/play transitions | `ARCHITECTURE_DECISIONS.md` |
| ADR-037 | Fish tiers (`small`/`medium`/`big`/`boss`) + 3-level catch-count progression; Scott is the boss tier | `ARCHITECTURE_DECISIONS.md` |
| ADR-038 | Rod owns session start/end (not World); `RodState.isFishing` streamed continuously; World reacts | `ARCHITECTURE_DECISIONS.md` |
| ADR-039 | Fight difficulty pass: tug-of-war, distance escape, continuous tension haptics, fight camera, **plus two live-tested corrections** (reel tension rate 0.85→0.55, tier differentiation via new resistance multipliers) — see below | `ARCHITECTURE_DECISIONS.md` |

Two smaller fixes bundled in along the way, no dedicated ADR (both logged in
`CHECKPOINT.md` only, since neither is a stable architectural decision):

- `EnvironmentSceneBuilder.swift`'s `NSColor`/`UIColor` cross-platform build
  break (was incorrectly "fixed" with `CGColor`, which satisfies neither
  platform's actual RealityKit color type).
- Debug tooling added and later disabled-but-kept (forward reference ray,
  pre-clamp aim-angle readouts) while diagnosing the cast-direction issue —
  search `// MARK: - Debug` in `WorldViewModel.swift` if you need to
  re-enable it.

------------------------------------------------------------------------

## ADR-039 in detail — this is where the window ended, and it has two live-tested corrections worth knowing before touching fight balance again

The fight-difficulty work went through three passes in this window, each
based on direct player feedback:

1. **First pass**: `baseReelTensionRate` 0.5 → 0.85, `basePullSpeed` 0.4 → 1.0,
   tug-of-war added (fish pull speed subtracted from player reel speed),
   distance-escape added (6 m allowance), continuous tension-band haptics
   added, fight camera added. Result: **unplayable** — 0.85 made even the
   weakest fish (`fish_a`) snap the line in under a second regardless of
   skill.
2. **Second pass** (reported: *"reel nya terlalu susah... impossible untuk
   grab fish A"*): `baseReelTensionRate` 0.55. Also: escapes now reset the
   hook to `.idle` instead of staying `.hookInWater` (was requested
   separately in the same message). Also: **all fight-tuning numbers were
   extracted into a new `Shared/Sources/Shared/Gameplay/FishFightConfig.swift`**,
   because the player asked for a hand-editable config file with docs instead
   of one-off code edits going forward. Read that file's own doc comments
   first if you're about to touch fight balance — they're the primary
   reference now, not this summary.
3. **Third pass** (reported: *"tingkat loncatan dari fish A - B - C - Scott
   masih kerasa gaada bedanya"* — the difficulty jump between tiers still
   doesn't feel different): added three new `FishFightConfig` fields
   (`pullRateResistanceMultiplier`, `pullSpeedResistanceMultiplier`,
   `escapeAllowanceResistancePenalty`) because `resistance`'s contribution to
   the fight formulas was being swamped by the shared base constants — every
   species produced a similar net tension rate regardless of tier.

**Current defaults, live in `FishFightConfig.swift`, all hand-reasoned, none
played**: `baseReelTensionRate` 0.55, `basePullSpeed` 0.7,
`pullRateResistanceMultiplier` 3.0, `pullSpeedResistanceMultiplier` 1.8,
`escapeAllowanceResistancePenalty` 3.5, `minEscapeDistanceAllowance` 2.0 m,
`escapeDistanceAllowance` 6.0 m. If fight balance still feels wrong when this
resumes, **start by reading `FishFightConfig.swift` directly** — every field
has a doc comment explaining what it does and how it interacts with the
others, and the ADR-039 Rationale section has the actual worked math (net
tension rate per tier, time-to-snap) if you need to re-derive numbers by hand
again rather than guessing.

------------------------------------------------------------------------

## Known issues, flagged but not fixed this window

- **ADR numbering collision**: there are two ADR-030s and two ADR-031s in
  `ARCHITECTURE_DECISIONS.md` — one set from this window's work, one set
  from the `feat/asset-integration` branch merge (camera authoring, transport
  delivery mode) that predates this window. Never resolved; flagged
  repeatedly, still there. Search for `# ADR-030` / `# ADR-031` (two matches
  each) if this needs cleaning up.
- **Rod's `ContentView.swift`** — commented-out Start/End Fishing buttons
  that were flagged mid-window turned out to already be fixed by the
  ADR-038 work (single dynamic Start/End Fishing button now in place,
  confirmed present in the final committed state). No action needed, just
  noting the earlier flag was resolved as a side effect of other work, not
  explicitly chased down.
- **`World`'s `SUPPORTED_PLATFORMS`** claims `iphoneos iphonesimulator
  macosx`, but this project's actual verification (and, as far as this
  window's context shows, actual usage) has only ever been macOS. The
  `EnvironmentSceneBuilder.swift` AppKit fix makes the iOS-simulator
  *typecheck* pass, but nothing in `World` has ever actually been run on
  iOS/iPadOS.

------------------------------------------------------------------------

## What "verified" means for everything in this window

Every entry above was verified the same way, every time: rebuild `Shared` as
both an `arm64-apple-macosx26.0` module and an `arm64-apple-ios26.0-simulator`
module directly from `find Sources/Shared -name "*.swift"`, then
`xcrun swiftc -typecheck` the full `World/World` file list against the macOS
module and the full `Rod/Rod` file list against the iOS-simulator module.
That's it. `xcodebuild` itself is blocked in this environment by a missing
signing certificate (pre-existing, unrelated to any of this work). **No
`xcodebuild`, no simulator run, no device run**, except for the specific
live-play feedback moments explicitly quoted throughout the ADRs (cast
direction's -174° measurement, the two fight-difficulty corrections above) —
those were the player actually running the app and reporting back, which is
also the *only* way any of the numeric tuning in this window has been
grounded in reality rather than hand-derived math.

------------------------------------------------------------------------

## Suggested next steps, roughly in priority order

1. **Play it.** Everything numeric in ADR-039 (and to a lesser extent the
   cast-direction correction in ADR-034) is a best guess dressed up as a
   config default. The single highest-value next action is a real session on
   real hardware, not another round of code changes.
2. If casting still feels off: re-check `debugRawAimDegrees`/
   `debugCorrectedAimDegrees` (the debug tooling from ADR-034 is disabled but
   not deleted — see `// MARK: - Debug` in `WorldViewModel.swift`) before
   assuming `aimCorrectionAngle` (currently 180°) needs to move again.
3. If the fight still feels wrong: edit `FishFightConfig.swift` directly, not
   the controller/haptics code — that's the entire point of ADR-039's config
   extraction.
4. The ADR-030/031 numbering collision is cheap to fix (pure renumbering, no
   logic change) whenever there's a slow moment — it's been flagged three
   times now without being resolved.
5. `MIGRATION_transport_to_corebluetooth.md`'s own acceptance criteria
   (Wi-Fi-off testing specifically, since that was the actual motivating bug
   for the CoreBluetooth migration) have never been checked. Worth doing
   before trusting the transport layer is actually fixed, not just
   typecheck-clean.
