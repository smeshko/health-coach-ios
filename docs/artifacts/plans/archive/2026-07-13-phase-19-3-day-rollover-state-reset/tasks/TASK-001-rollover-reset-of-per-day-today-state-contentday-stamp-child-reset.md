# TASK-001: Rollover reset of per-day Today state (contentDay stamp + child reset)

Depends on: None
Suggested commit: `fix(today): reset per-day child state on Sofia-day rollover (contentDay stamp)`

## Goal

Crossing a Sofia midnight with the app resident resets every per-day piece of
`TodayFeature.State` (check-in child, session child, restored pick, readiness, refresh
throttle) at the rollover detection point, and rollover is detectable from ALL terminal
states — not just `.ready` — via a `contentDay` stamp.

## Files

- `Sources/Features/TodayFeature/Sources/TodayFeature.swift` —
  - `State` gains `contentDay: Date?` (the Sofia `startOfDay` the current content was
    orchestrated for; single write point in orchestration).
  - A `static func rolloverReset(_ state: inout State)` (or private mutating method)
    with the explicit per-day contract: `checkIn = .init()`, `session = nil`,
    `restoredSelection = nil`, `readiness = nil`, `lastRefreshAttemptAt = nil`, and
    **`isBackgroundRefreshing = false`** (validation round-1 #1: the rollover's
    `cancelInFlight` kills an in-flight background pass, so its resolved/failed action
    never arrives to clear the flag — a stuck "Updating…" pill otherwise).
    `zones`/`lastSyncedAt` deliberately survive (not per-day — see RESEARCH inventory).
  - `sceneBecameActive` guard shape (validation round-1 #5), explicit:
    - **Rollover leg** compares `contentDay` (one detector, replacing the `.ready`-only
      `brief.date` comparison) and applies to every stamped state — terminals
      (`.ready`, `.checkInRequired`, `.error`, **`.syncFailed`** — round-1 #7) AND
      in-flight `.syncing`/`.generating` (an overnight-suspended chain restarts safely:
      `cacheFirstOpenEffect` is `cancelInFlight` on the shared orchestration CancelID).
      `nil` `contentDay` (fresh state, orchestration not yet run) must NOT trigger it.
    - **Same-day staleness leg stays `.ready`-gated exactly as today** —
      `isStale(nil, nil) == true`, so widening it would fire a background refresh over
      a same-day `.checkInRequired` and break `test_sceneActive_nonReady_isNoOp`.
    - On rollover: `rolloverReset` + the existing `cacheFirstOpenEffect()`.
- `Sources/Features/TodayFeature/Sources/TodayOrchestration.swift` — the stamp
  mechanism (validation round-1 #3): effect factories cannot mutate state, so change
  `cacheFirstOpenEffect`/`orchestrationEffect` signatures to take `_ state: inout
  State` and stamp `state.contentDay = today` there, before building the effect — the
  factories are the single conceptual write point; their four reducer trigger sites
  (`onAppOpen`, `retryTapped`, `.checkIn(.delegate(.checkInSaved))`, the rollover
  branch) inherit the stamp with zero per-site code. **Do NOT stamp at the background
  trigger sites** (validation round-2 #1, reversing round-1 #4's mitigation):
  `pullToRefresh` is `.ready`-gated but not same-day-gated — stamping there at 00:01
  writes `contentDay = today` OVER yesterday's un-reset children and permanently masks
  the rollover (and on a failed pass, masks it with yesterday's content still up). A
  cross-midnight background pass that hydrates a next-day brief leaving a stale stamp
  is the CORRECT recovery: the next activation resets children and re-gates (new day ⇒
  new check-in; today's persisted pick survives via `_selectionLoaded`). The staleness
  leg needs no stamp either — it runs only when the rollover leg found
  `contentDay == today` **or `nil`** (the nil fall-through is what keeps the existing
  nil-stamp same-day staleness tests green — round-3 #1: do NOT literalize a
  `== today` guard onto the staleness leg). Also update the two now-lying doc comments
  in `TodayFeature.swift` (round-2 #3 / round-3 #3): `Action.sceneBecameActive`'s
  "from `.ready` only" (:104–105) and the reducer branch's "non-ready states are
  already showing the right thing" (:216–217).
- `Sources/Features/TodayFeature/Tests/TodayFeatureTests/TodayFeatureSceneStalenessTests.swift`
  — new cases:
  (a) rollover from `.ready` with ALL per-day fields seeded stale (checkIn.lastSavedAt +
  existing, session with a non-zero `selectedIndex`, restoredSelection, readiness,
  lastRefreshAttemptAt, `isBackgroundRefreshing = true`) → all reset + re-orchestration
  received;
  (b) rollover from `.checkInRequired` (yesterday's `contentDay`) → re-orchestrates
  (gate re-runs for the new day) — the closed gap; parameterize over `.error` and
  `.syncFailed` too (round-1 #7);
  (c) rollover from in-flight `.syncing`/`.generating` with a stale stamp →
  re-orchestrates (cancelInFlight makes the restart safe);
  (d) same-day activation with everything seeded → nothing reset (existing throttle
  tests keep passing);
  (e) hydrate-after-rollover: post-reset, a new-day hydrate prefers index 0 (no stale
  pick seed) unless `._selectionLoaded` delivered today's own persisted pick.
  EXISTING-TEST EDIT (round-1 #2): `test_sceneActive_dayRollover_reOrchestrates_hitsCheckInGate`
  seeds no `contentDay` — under the nil-must-not-trigger rule it stops receiving
  `._checkInRequired`; seed it with yesterday's day (intent unchanged). The other scene
  tests survive a nil stamp.

## Acceptance

- [ ] Test (a): every per-day field reset in the rollover branch; `zones` and
  `lastSyncedAt` survive.
- [ ] Tests (b)/(c): non-`.ready` rollover re-orchestrates (previously `return .none`).
- [ ] Test (d): same-day activation mutates none of the per-day fields; existing
  staleness/throttle tests pass unchanged.
- [ ] Test (e): yesterday's pick cannot seed today's carousel through
  `state.session?.selectedSession` or `restoredSelection`.
- [ ] `contentDay` is stamped ONLY by the `inout` factories (asserted after
  `.onAppOpen` — round-1 #10 — and after rollover re-orchestration); `pullToRefresh`
  and the staleness leg leave it untouched (round-2 #1 — asserted: a pull does not
  move a stale stamp).
- [ ] `isBackgroundRefreshing` is false after a rollover that interrupted an in-flight
  background pass (no stuck "Updating…" pill).

Evidence: TodayFeatureTests suite output with the new scene-staleness cases green.

## Steps

### RED
- [ ] Add cases (a)–(e); (a)(b)(c)(e) fail against the current no-reset `.ready`-only
  detector.

### GREEN
- [ ] `contentDay` + `rolloverReset` + the detector rewrite + orchestration stamping.

### REFACTOR
- [ ] Keep the per-day contract documented on `rolloverReset` (what survives and WHY);
  confirm the whole TodayFeature suite (incl. cache-first + background-degrade tests)
  is green. **Expected mechanical sweep (round-2 #2): ~29 exhaustive
  `store.send(.onAppOpen/.retryTapped/…)` calls across ~5 test files now mutate
  `contentDay` and each needs a one-line `$0.contentDay = <today>` assert in its
  trailing closure — this is RED noise by design (no internal stamping action escape
  hatch), not a design bug.

## Notes

- `TestStore` exhaustivity: the reset mutations happen in the `sceneBecameActive`
  reducer turn — assert them in that `send` block, then `receive` the orchestration
  actions as the existing rollover test does.
- Do NOT reset inside `._checkInRequired` or `hydrate` (D1) — same-day flows reach
  those and must keep typed-but-unsaved answers.
