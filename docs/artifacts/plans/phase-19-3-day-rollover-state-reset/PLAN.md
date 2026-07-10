# Plan: Day-rollover state reset

Status: in-progress
Branch: fix/phase-19-3-day-rollover-state-reset
Risk: medium
Epic: 19 — Make the numbers trustworthy (audit wave 2) ([epic](../../epics/19-trustworthy-numbers.md))
Phase: 19.3 — Day-rollover state reset
Linear: none
Created: 2026-07-10

## Goal

Crossing a Sofia midnight with the app resident never carries yesterday's answers into
today: the check-in gate shows unanswered with no stale "Last saved" footer, yesterday's
workout pick cannot seed today's carousel, and the forced-REST override card renders a
resolved zone chip instead of the hardcoded `nil` placeholder.

## Scope

- `Sources/Features/TodayFeature/Sources/TodayFeature.swift` — a `rolloverReset`
  mutation of the per-day child state, invoked in `sceneBecameActive`'s rollover branch;
  extend rollover detection beyond `.ready` via a `contentDay` stamp.
- `Sources/Features/TodayFeature/Sources/TodayOrchestration.swift` — stamp `contentDay`
  at orchestration entry (single source).
- `Sources/Features/TodayFeature/Sources/CheckInComponent.swift` +
  `CheckInSection.swift` — day-guard the "Saved earlier today" footer copy so a stale
  `existing` can never claim today.
- `Sources/Features/TodayFeature/Sources/TodayReadyContent.swift` +
  `Sources/Features/TodayFeature/Sources/Session/SessionFeature.swift` — in-module
  `Zones.range(for:)` helper; forced-REST branch resolves the override card's
  `zoneRange` from `store.zones` + the override's `zoneTarget`.
- Tests in `Sources/Features/TodayFeature/Tests/TodayFeatureTests/` (extend
  `TodayFeatureSceneStalenessTests` + component tests).

## Out of Scope

- A timer/clock-driven midnight observer — rollover is detected on `sceneBecameActive`
  (the D6 design); an app foregrounded across midnight re-activates its scene, which is
  the epic's validation scenario ("advance the clock across a Sofia midnight with the
  app resident").
- Weekly-tab rollover (ISO-week freshness) — Epic 20 Phase 20.3.
- Re-editing an already-saved check-in after the brief loads (existing OPEN item from
  8.5) — unrelated affordance.
- Backend phases 19.4/19.5.

## Research Summary

See [RESEARCH.md](./RESEARCH.md). Load-bearing findings:

- Rollover detection exists ONLY in `sceneBecameActive` (TodayFeature.swift:215–224) and
  ONLY over `.ready` (`guard case let .ready(brief, _)`); it compares
  `calendar.startOfDay(for: brief.date) != today` and re-runs `cacheFirstOpenEffect()`
  — but resets **no state**. Terminal `.checkInRequired`/`.error` states from yesterday
  are never rollover-checked (the guard returns `.none`).
- Per-day state that survives: `checkIn.lastSavedAt` + `checkIn.existing` (the footer),
  `session` (whose computed `selectedSession` feeds hydrate's
  `state.session?.selectedSession ?? state.restoredSelection` preferred-pick),
  `restoredSelection`, `readiness`. `zones` is not per-day (D1 19.2 refreshes it
  per-sync); `lastSyncedAt` is not per-day (mirrors the watermark).
- The check-in **gate** itself is day-keyed and correct (`checkInRepository.current(day)`
  fetches by Sofia `startOfDay` PK) — the bug is purely stale child *state* surviving
  in memory and rendering (footer/carousel) before or despite re-orchestration.
- Selection persistence is day-keyed and correct (`sessionSelectionRecord` PK =
  Sofia day; a new day reads `nil`) — the seed path is in-memory `selectedSession`.
- The forced-REST chip gap is a literal hardcode: `zoneRange: nil` at
  TodayReadyContent.swift:64 with the comment "reconciled when that lands" — and "that"
  (zones in `TodayFeature.State`) landed in Phase 8.4/12.1 and got fresher in 19.2;
  `SafetyRestView` already takes `zoneRange: ZoneRange?` and renders the chip when
  non-nil. Zone resolution exists as `SessionFeature.State.zoneRange(for:)`
  (exhaustive switch over `z1…z5`) but needs the session child, which is `nil` on a
  tripped day — hence the in-module `Zones` extension both call sites share.
- Test harness: `TodayFeatureSceneStalenessTests` already pins
  rollover→`._checkInRequired` re-orchestration with `$0.date = .constant(now)` +
  `.europeSofia`; no test asserts child-state reset, footer copy, or the chip.

## Decisions

See [DECISIONS.md](./DECISIONS.md) — D1 reset-at-detection vs reset-in-gate-actions;
D2 `contentDay` stamp for non-`.ready` rollover; D3 footer day-guard as defense in
depth; D4 in-module `Zones.range(for:)` (not DomainModels — Epic 20.1 owns SSOT moves).

## Risks

- Resetting `session = nil` on rollover unmounts the carousel until the new-day hydrate
  — correct (the new day's gate/loading are "honest" per the existing D6 exemption
  comment). The `briefState` flip happens a reducer-turn later (async repo reads), so
  there is a ≥1-frame window rendering yesterday's `.ready` shell with the children
  gutted — accepted (validation round-1 #8): scene-activation timing hides it, and the
  alternative (also moving `briefState` in the reset) invents a synthetic loading state
  outside the orchestration's ownership.
- A background pass that straddles midnight can hydrate a next-day brief while
  `contentDay` stays yesterday — the next activation then resets children and re-gates
  over just-hydrated content. Accepted as the CORRECT recovery, not churn (round-2 #1):
  the new day genuinely needs a new check-in, and today's persisted pick survives via
  `_selectionLoaded`. Background triggers deliberately do NOT stamp — stamping there
  would mask rollover entirely (`pullToRefresh` is `.ready`-gated, not same-day-gated).
- Resetting `lastRefreshAttemptAt` on rollover interacts with the same-day staleness
  throttle tests — reset is scoped to the rollover branch only; same-day throttle
  behavior (pinned by `TodayFeatureSceneStalenessTests`) is untouched.
- The `contentDay` stamp adds one more piece of state that must be maintained — single
  write point (orchestration entry) keeps it from drifting; tests pin it.
- Snapshot ripple: the forced-REST chip renders only when an `active_recovery` override
  carries `zoneTarget` AND zones are present — existing SafetyRest snapshots pass
  `zoneRange: nil` fixtures and stay byte-identical; a new chip-resolved snapshot (if
  added) needs `make record-snapshots` on the canonical sim (memory: env-prefix
  reaches the runner).
- `CheckInComponent`'s own `.task` reload already self-corrects `existing` for the new
  day — the day-guard (TASK-002) covers only the render window before it lands and any
  missed-rollover path; it must not change same-day footer behavior.

## Acceptance Criteria

- [ ] Crossing a Sofia midnight and re-activating the scene from `.ready` resets:
  check-in child (no `lastSavedAt`, no `existing`, answers back to defaults), `session`
  (nil), `restoredSelection` (nil), `readiness` (nil), `lastRefreshAttemptAt` (nil),
  and `isBackgroundRefreshing` (false — a rollover-cancelled background pass can never
  strand the "Updating…" pill) — pinned by a `TodayFeatureSceneStalenessTests` case
  that seeds all of them with yesterday's values.
- [ ] A rollover from a non-`.ready` state stamped with yesterday's `contentDay` also
  re-orchestrates and resets — terminals (`.checkInRequired`, `.error`, `.syncFailed`)
  and in-flight `.syncing`/`.generating` (cancelInFlight restart) alike.
- [ ] Same-day scene activation resets nothing and keeps the existing staleness/throttle
  behavior (existing tests pass after the mechanical sweep: the one existing rollover
  test gains a `contentDay` seed, and ~29 exhaustive trigger-action sends across ~5
  files gain a one-line `$0.contentDay` assert — intent unchanged everywhere,
  round-2 #2).
- [ ] Yesterday's pick cannot seed today's carousel: after rollover reset, hydrate's
  preferred pick is `nil` (falls to the primary at index 0) unless today's own persisted
  selection exists — pinned by a hydrate-after-rollover test.
- [ ] The "Saved earlier today" footer renders only when `existing.date` is today
  (Sofia); yesterday's `existing` renders no footer — component-level test.
- [ ] The forced-REST override card resolves its zone chip: an `active_recovery`
  override with `zoneTarget: .z1` + loaded zones renders the Z1 bpm range; `rest`/
  `mobility` overrides (no `zoneTarget`) still render no chip. The hardcoded
  `zoneRange: nil` and its "when that lands" comment are gone.
- [ ] All package tests green on the canonical sim; SafetyRest/Today snapshots
  unchanged unless a new chip fixture is deliberately added (then re-recorded on the
  pinned device).

## Tasks

Task state lives here. Tasks are appended by `scripts/add_task.py` and
`scripts/add_final_task.py`. Update the checkboxes as work progresses.

- [x] TASK-001: Rollover reset of per-day Today state (contentDay stamp + child reset)
- [x] TASK-002: Day-guard the check-in footer copy
- [x] TASK-003: Resolve the forced-REST override card zone chip
- [ ] TASK-004: Final Validation
