# WINDOW_2.md — Session Handoff

Written because this session's context window is getting long and a handoff was requested. This
is a **navigation summary**, not a replacement for `CHECKPOINT.md` (the full, permanent,
entry-per-task history) or `ARCHITECTURE_DECISIONS.md` (the full ADR text) — both already have
complete detail for everything below. This file exists so the next window can get oriented in one
read instead of re-deriving context from the full logs. Same purpose as `Archive/WINDOW_1.md`
(the previous window's handoff, now archived — read it only if you need the ADR-030 through
ADR-039 history; everything since is covered here or in the full logs).

------------------------------------------------------------------------

## ⚠️ Git state — read this before doing anything else

`dev` and `origin/dev` are both at commit `68d3f4d` ("feat: current update progress") —
already pushed, safe. **But the working tree right now has real, substantial, uncommitted
changes on top of that** (see exact file list below) — this is the freshest work in this
window (ADR-056, ADR-057, and ADR-057's live-tested correction). If you're picking this up in a
fresh session, check `git status`/`git diff --stat` yourself before assuming anything about
what's committed — don't trust this file's snapshot if time has passed.

```text
$ git status --short
 M ARCHITECTURE_DECISIONS.md
 M CHECKPOINT.md
 M CtSPoC.xcworkspace/xcuserdata/cindyram.xcuserdatad/UserInterfaceState.xcuserstate
 M Rod/Rod/Sensors/MotionManager.swift
 M Rod/Rod/ViewModel/RodViewModel.swift
 M SOFTWARE_ARCHITECTURE_DOCUMENT.md
 M Shared/Sources/Shared/Gameplay/CastResolver.swift
 M Shared/Sources/Shared/Gameplay/RodMotionInterpreter.swift
 M Shared/Sources/Shared/Models/Rod/RodState.swift
 M World/World/ContentView.swift
 M World/World/Views/CastMeterView.swift
```

**One git surprise already happened once this window** and may happen again: partway through,
HEAD was found **detached** at a commit that `dev` also happened to point to (likely from an
external tool — Xcode's Source Control panel is the leading suspect, not anything this session
did directly). It was resolved safely with a plain `git checkout dev` (a no-op for the working
tree, since `dev` and the detached commit were identical) — nothing was lost, but if you see
`HEAD detached at <sha>` again, check `git branch -v`/`git log --oneline -3` before assuming
anything is wrong; it may just need the same re-attach.

There are also **five `git stash` entries that are not this session's** (`stash@{0}` through
`stash@{5}` as of this writing, mixing entries from before and during this window) — none were
created or touched by this session except one (already dropped, was pure `.xcuserstate` noise).
Leave the rest alone; they aren't yours to manage.

------------------------------------------------------------------------

## TL;DR — what happened this window, roughly in order

1. **Read the full project doc set** (`CLAUDE.md`, `AGENTS.md`, `CHECKPOINT.md`,
   `ARCHITECTURE_DECISIONS.md`, `SOFTWARE_ARCHITECTURE_DOCUMENT.md`,
   `SPATIAL_CONTROLLER_DOCUMENT.md`) and, on request, assessed which were redundant/stale.
2. **Documentation cleanup** (already committed, in `dev` history): archived
   `SPATIAL_CONTROLLER_DOCUMENT.md` and `WINDOW_1.md` to `Archive/`, extracted the long-dead
   Sprint 0-8 roadmap out of `AGENTS.md`/`SOFTWARE_ARCHITECTURE_DOCUMENT.md`, fixed a real
   staleness bug in `CLAUDE.md` (it still described the transport as MultipeerConnectivity, long
   since replaced by CoreBluetooth per ADR-035).
3. **Nearby Interaction audit (ADR-041)**: confirmed by direct code audit — not doc-reading — that
   NI is fully wired (Rod owns the session per ADR-014) but **not read by any gameplay/rendering
   code anywhere**, only debug display. Left the code as-is, fixed several docs that had drifted
   into claiming otherwise.
4. **Reel-in motion fixes (ADR-042, ADR-043)**: hook now stays at water height until near the dock
   instead of rising diagonally the instant reeling starts; a follow-up (found via a teammate's
   parallel branch, `feat/playtest-refine`, merged in — see below) moved the lift target off the
   dock's actual measured footprint so the bobber stops clipping through the pier deck.
5. **A real merge with a teammate's parallel work.** `origin/main` had moved via a `feat/playtest-refine`
   branch (dock-approach fix + a catch cutscene, ADR-044–048) that **independently used the same
   ADR numbers** as four unrelated features built in this window. Resolved by merging
   `origin/main` into `dev` and renumbering this window's four ADRs from 044–047 to **049–052**
   (keeping the teammate's 044–048 as the already-canonical numbering on `main`) — every
   cross-reference across all four docs was updated to match. **Current highest ADR number is
   057** (plus two in-place "live-tested correction" amendments, to ADR-054 and ADR-057 — see
   below). Check `ARCHITECTURE_DECISIONS.md`'s own top entry before adding a new one; this
   collision has already happened once.
6. **Four features, one request ("3 jobs")**: device pairing allowlist (**ADR-049**), an explicit
   "Start Casting" arm gate (**ADR-050**), a rod-rig pass — bend smoothing, a placeholder reel
   spin, a real fix to a long-standing line-follow bug (**ADR-051**), and a floating/bobbing
   idle-hook animation (**ADR-052**).
7. **Fight direction mechanic (ADR-053)**: a hooked fish now juks left/right on a randomized
   5–10s timer per fight; the player must counter by rolling the rod the opposite way
   (`RodState.roll`) or take a tension penalty. Shown on World's `LineTensionView`, not Rod (Rod
   owns no gameplay HUD).
8. **Cast power overhaul, three passes in a row**:
   - **ADR-054**: switched cast power from ADR-032's pull-back-*distance* measurement to a
     hold-*duration* timer ("hold longer = more power"). Also boosted every Rod haptic pattern's
     intensity, eased fish tier 3/4 (`fish_c`/`scott`) difficulty, added a "Reset Progress" button
     (**ADR-055**).
   - **Live-tested correction to ADR-054** (same day): the hold timer reset on a single noisy
     classification-flicker frame, silently discarding charge — fixed by only starting the timer
     when it's genuinely unset, not on every frame classification happens to flip to `.cast`.
   - **ADR-056**: removed the flick-speed bonus from cast power *entirely* — power is now purely
     a function of hold duration; the flick is only ever the release trigger. Cleaned up the
     now-fully-dead `angularVelocity`/per-axis-rotation-rate chain this exposed, all the way back
     to `MotionManager`. **Also found `CastMeterView`'s call site had been commented out in
     `World/ContentView.swift`** the whole time — re-enabled it, added a live "Holding X.Xs"
     timer readout next to the existing power bar.
   - **ADR-057**: turned the hold-duration ramp into a **continuously oscillating** timing
     mini-game (`power = (1 - cos(phase)) / 2`, phase driven by hold duration) — "meteran naik
     turun perlahan," golf-swing-meter style. The flick locks in whatever the oscillating value
     is at that exact instant.
   - **Live-tested correction to ADR-057** (same day): re-arming ("Start Casting" again) shortly
     after a release could read as "power is already maxed the instant I press the button" —
     root cause was Rod's local post-release cooldown timer replaying the *previous* cast's frozen
     power regardless of a fresh arm. Fixed by having a fresh arm always cancel any lingering
     cooldown. Also slowed the oscillation period 2.0s → 3.5s per the same feedback.

------------------------------------------------------------------------

## Full ADR list this window, with pointers

| # | What | Status |
|---|------|--------|
| ADR-041 | NI confirmed present but not load-bearing for V1 gameplay | Docs-only fix |
| ADR-042 | Reel-in stays at water height until near the dock | Code |
| ADR-043 | Hook lift target moved off the dock's measured footprint | Code (landed via teammate merge, see below) |
| ADR-044–048 | Dock-approach guaranteed-speed lift + catch cutscene | **Not this session's work** — a teammate's parallel branch (`feat/playtest-refine`), merged in |
| ADR-049 | Device pairing allowlist over CoreBluetooth | Code |
| ADR-050 | Cast attempts require an explicit "Start Casting" arm | Code |
| ADR-051 | Rod rig pass: bend smoothing, placeholder reel spin, line-follow fix | Code |
| ADR-052 | Floating bobber: idle bob + pre-bite "interest dip" | Code |
| ADR-053 | Fight direction: timed left/right juking, rod-roll counter | Code |
| ADR-054 | Cast hold timer (+ correction), stronger haptics, eased tier 3/4 | Code |
| ADR-055 | Reset Progress button | Code |
| ADR-056 | Cast power drops flick entirely; live timer shown in World; `CastMeterView` re-enabled | Code |
| ADR-057 | Cast power becomes an oscillating timing mini-game (+ correction) | Code |

Each has a full `ARCHITECTURE_DECISIONS.md` entry (search the ADR number) and a full
`CHECKPOINT.md` entry (search the ADR number or the section title in quotes).

------------------------------------------------------------------------

## What "verified" means for everything in this window

Unchanged from `Archive/WINDOW_1.md`'s own standing note, still true: every entry above was
verified via `swiftc -typecheck` against hand-built `Shared` modules (both an
`arm64-apple-macosx26.0` module and an `arm64-apple-ios26.0-simulator` module, built directly
from `find Sources/Shared -name "*.swift"`), then the full `World/World`/`Rod/Rod` file lists
typechecked against them. `git diff --check` run after every entry. **No `xcodebuild`, no
simulator run, no device run, for anything in this window.** `xcodebuild` remains blocked in this
environment by a missing signing certificate. The cast-timer/oscillating-meter work in particular
has already needed two rounds of "reported as buggy after playing, root-caused, fixed" —
treat every numeric constant in this window (oscillation period, hold-duration bounds, haptic
intensities, fight-direction timers/thresholds, the two eased resistance values) as a first-pass
guess, not a tuned value.

------------------------------------------------------------------------

## Known issues, carried over or newly flagged

- **ADR-030/031 numbering collision** (flagged in `Archive/WINDOW_1.md`, still unfixed): two
  unrelated ADR-030s and two unrelated ADR-031s exist in `ARCHITECTURE_DECISIONS.md` from
  different branches merged long ago. Cheap to fix (pure renumbering), flagged repeatedly across
  multiple windows now, still not done.
- **`FishCatalog.swift`'s tier resistance values have kept moving** past what this session last
  set. Current values as of this writing: `fish_a` 0.35, `fish_b` 0.50, `fish_c` 0.65, `scott`
  0.70 — check the file directly rather than trusting any ADR's stated numbers, since this has
  been hand-retuned more than once outside of a formal ADR-documented pass.
- **Rod's Developer Details `DisclosureGroup` is commented out** in `Rod/Rod/ContentView.swift`
  (with a stray trailing-whitespace line at line ~60 that `git diff --check` still flags) — this
  predates this session's own edits to that file; left alone throughout, per this project's
  standing precedent of not touching state that looks like someone else's in-progress work.
- **Nothing in this window has been played on a real device**, per the "What verified means"
  section above. This is the single most load-bearing fact for anyone picking this up next.

------------------------------------------------------------------------

## Suggested next steps, roughly in priority order

1. **Commit and push the uncommitted work** (ADR-056/057 + both corrections) if it hasn't
   happened by the time you read this — check `git status` first, per the warning at the top of
   this file.
2. **Play it.** Specifically the cast mechanic — it's had the most churn (three ADRs, two
   live-tested corrections, all in this one window) and is the most likely thing to still feel
   wrong. The oscillation period (3.5s) and the whole "timing game" feel are unverified.
3. If the fight-direction mechanic (ADR-053) gets played: the roll threshold
   (`fightDirectionRollThreshold`, 0.15 rad) and the relief/penalty magnitudes are pure guesses —
   check whether countering the fish's pull actually reads as achievable/rewarding.
4. The ADR-030/031 numbering collision above — still cheap, still not done, now flagged in a
   third handoff document.
5. `MIGRATION_transport_to_corebluetooth.md`'s own Wi-Fi-off acceptance criteria (from way back,
   ADR-035) have still never been checked, per every prior window's own notes. Worth doing before
   trusting the transport layer beyond "it typechecks."
