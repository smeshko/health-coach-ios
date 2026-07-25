# Adversarial Validation — Round 2

**Run:** 2026-07-24 12:20 UTC
**Plan:** widget-infrastructure
**Status at start:** draft
**Prior rounds in scope:** validation/round-1.md
**Reviewer:** inline validator lens (Codex-unavailable fallback — the foreground `codex adversarial-review`
run reproducibly exceeds the 10-minute harness cap and is SIGTERM'd mid-finalize; per the shared protocol
the round runs with the same adversarial framing applied by the validator, verifying the round-1 edits and
re-sweeping for anything they introduced).

## Codex output

<!-- Codex-unavailable fallback: inline adversarial re-check of the applied edits. -->

Re-checked each round-1 apply against current source and for edit-induced problems:

- **#1 (TASK-003, compile break) — sufficient.** `reduceSessionRouting` (AppFeature+SessionRouting.swift)
  has a single exhaustive `switch action` whose only non-`return`-early arm is the explicit catch-all
  `case ._restoreSession, ._tokenChecked, .notificationOpened, .onboarding, .main:` with no `default`.
  Adding `.deepLink` there (returning `.none`, routed in `body`) restores exhaustiveness and does not
  double-handle: `body`'s own switch owns the routing, `reduceSessionRouting` no-ops it — the exact split
  `notificationOpened` already uses. No other exhaustive switch over `AppFeature.Action` exists
  (`ActionLogging.swift` is generic over `Base.Action`; `MainTabs.swift` switches `MainTabs.Action`, a
  different enum). Edit is complete.
- **#2 (TASK-002, stale selectedSession) — sufficient, no new gap.** The same-Sofia-day guard reuses the
  TASK-001 `WidgetDailySnapshot.isCurrent(at:calendar:)` helper (or a Sofia `startOfDay` equality),
  available to Live via its dependency on the interface module; the added acceptance case (cross-day drop)
  is constructible against `WidgetSnapshotStore(directoryURL:)`. `weekly`/`checkIn` stay preserved
  verbatim (their own render-time `isCurrent` checks own their staleness — not the merge's job), so the
  guard is correctly scoped to `selectedSession` only.
- **#3 (TASK-002/PLAN Risks, lost update) — sufficient, no conflict.** Serializing the live client's
  writes through a single actor leaves the pure `merge(daily:into:)` free function and the synchronous
  `WidgetSnapshotStore(directoryURL:)` host tests untouched (they exercise the primitives directly, not
  the actor). The struct-vs-actor split is left to the implementer under an invariant (concurrent
  `update*` cannot lose sections), which is the right altitude for a plan — no over-specification.
- **#4 (TASK-007, acceptance coverage) — sufficient.** The four added checklist lines map 1:1 to PLAN.md
  acceptance criteria 5, 6, 7, 8; criteria 1–4 were already covered by existing TASK-007 steps. Every
  PLAN.md acceptance criterion now has a named evidence line in the final-validation task.

New issues surfaced this round: none. No apply rows.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| — | (no new findings; round-1 edits verified sufficient) | — | — | Round-2 re-sweep found the four applies complete and self-consistent, and no problems introduced by them. | — |
