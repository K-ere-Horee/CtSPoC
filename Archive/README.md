# Archive

Superseded or stale documentation, kept for history. Nothing in this folder
reflects current project state — for that, read `CHECKPOINT.md`,
`ARCHITECTURE_DECISIONS.md`, `SOFTWARE_ARCHITECTURE_DOCUMENT.md`, and
`GAMEPLAY_ARCHITECTURE_V1.md` at the project root.

- **`SPATIAL_CONTROLLER_DOCUMENT.md`** — the original pre-gameplay spatial
  controller pitch. Fully superseded by `SOFTWARE_ARCHITECTURE_DOCUMENT.md`
  (technical) and `GAMEPLAY_ARCHITECTURE_V1.md` (product). Its `RodState`
  snippet and milestone roadmap are both stale — `RodState` has grown many
  fields since (`orientation`, `castSolution`, `action`, `reelSpeed`,
  `motionPhase`, `castPower`, `isFishing`) and every milestone listed shipped
  long ago.
- **`WINDOW_1.md`** — a one-time context-window handoff summary (covers
  ADR-030 through ADR-039). By its own header it was never meant to replace
  `CHECKPOINT.md`/`ARCHITECTURE_DECISIONS.md`, only to speed up re-orienting
  in a fresh session. Archived once its content was confirmed fully captured
  in those two files. If a future session writes another handoff note like
  this, archive the previous one the same way rather than letting them
  accumulate at the project root.
- **`COMPLETED_SPRINT_ROADMAP.md`** — the original Sprint 0-8 roadmap, moved
  out of `AGENTS.md`/`SOFTWARE_ARCHITECTURE_DOCUMENT.md` (both carried a
  near-identical copy). All eight sprints are done; current state lives in
  `CHECKPOINT.md`/`ARCHITECTURE_DECISIONS.md` instead.

Archived 2026-07-20 as part of a documentation cleanup pass (see
`CHECKPOINT.md`'s matching dated entry). A known, still-unresolved issue from
that same pass: `ARCHITECTURE_DECISIONS.md` has two unrelated ADR-030s and two
ADR-031s (one set from gameplay tuning, one from the asset-integration merge)
— flagged repeatedly, not fixed here, since renumbering ADRs is a separate
task from archiving stale docs.
