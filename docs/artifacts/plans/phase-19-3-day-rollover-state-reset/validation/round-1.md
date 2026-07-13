# Adversarial Validation — Round 1

**Run:** 2026-07-10
**Reviewer:** subagent (general-purpose, adversarial framing — Codex usage-capped)
**Plan:** phase-19-3-day-rollover-state-reset
**Status at start:** draft

## Reviewer output

<!-- Subagent output verbatim below this line. Do not edit. -->

# Adversarial validation — phase-19-3-day-rollover-state-reset

**Verdict summary:** Plan is well-grounded — every line/symbol claim checked out against post-PR-#60 staging (detector at TodayFeature.swift:215–234, hardcode at TodayReadyContent.swift:64, footer at CheckInSection.swift:63–69, `zoneRange(for:)` at SessionFeature.swift:77–86, `Card.activeRecovery` + `SessionBlock.zoneTarget` make the chip scenario constructible, cancellation via the shared `CancelID.orchestration` w/ `cancelInFlight` is sound, `cachedDailyBrief` same-day peek is pinned by `DailyCachePolicyTests`). **10 findings: 8 apply (5 med, 3 low), 1 defer, 1 cosmetic-apply.** The med findings are all fixable in the plan text; none invalidates the design.

1. **[med / apply]** `rolloverReset` omits `isBackgroundRefreshing = false`. A rollover while a background pass is in flight (`isBackgroundRefreshing == true`) cancels that pass via `cacheFirstOpenEffect`'s `cancelInFlight`, so `._backgroundRefreshResolved/Failed` never arrives — and no downstream path clears the flag (`._checkInRequired`, the blocking chain, and `._briefResolved` all leave it). Stuck "Updating…" pill on the new day. Add it to the reset contract + seed it in test (a). → TASK-001, PLAN criterion 1, RESEARCH inventory table.

2. **[med / apply]** The existing rollover test breaks under the plan's own rule. `test_sceneActive_dayRollover_reOrchestrates_hitsCheckInGate` constructs `.ready(yesterday)` with `contentDay` nil; the plan replaces the `brief.date` comparison with `contentDay` and mandates "nil must NOT trigger" — so that test's `receive(\._checkInRequired)` fails. TASK-001 claims existing tests pass unchanged; this one needs a `contentDay: yesterday` seed (the other four scene tests survive nil). → TASK-001 (RED/acceptance), PLAN criterion 3 wording.

3. **[med / apply]** The `contentDay` single-write-point is unimplementable as written. TASK-001 says stamp "at the reducer-side entry" in TodayOrchestration.swift — but `cacheFirstOpenEffect()`/`orchestrationEffect(refresh:)` are effect factories that don't take state, and effects can't mutate state. There are four reducer trigger sites (`onAppOpen`, `retryTapped`, `.checkIn(.delegate(.checkInSaved))`, the rollover branch). Specify the mechanism: change the factory signatures to `(_ state: inout State)` and stamp before building the effect — otherwise an implementer invents a new internal action or scatters four ad-hoc writes. → TASK-001.

4. **[med / apply]** Background-refresh triggers don't stamp, and D2 silently swaps server truth (`brief.date`) for a client stamp. `pullToRefresh`/same-day-staleness run `backgroundRefreshEffect` outside "orchestration entry"; a pass straddling midnight can hydrate a changed (next-day) brief via `._backgroundRefreshResolved` while `contentDay` stays yesterday → spurious reset-and-re-orchestrate on the next activation (which now also wipes children). Either stamp at the background trigger sites too (they're same-day by construction, cheap) or add the accepted-churn line to Risks; and D2 should note the deliberate semantic change away from `brief.date`. → DECISIONS D2, TASK-001, PLAN Risks.

5. **[med / apply]** Guard-restructure hazards unstated. (a) The same-day staleness leg must stay `.ready`-gated: `isStale(nil, nil) == true`, so a widened guard would fire a background refresh over a same-day `.checkInRequired` and break `test_sceneActive_nonReady_isNoOp`. (b) The plan says rollover covers "ALL terminal states" but never says whether in-flight `.syncing`/`.generating` (which will carry a stamped `contentDay`) participate — an overnight-suspended chain arguably should (cancelInFlight makes restart safe), but the guard shape must be explicit. One paragraph in TASK-001. → TASK-001.

6. **[med / apply]** TASK-003's headline acceptance isn't observable as specced. The derivation `override.zoneTarget.flatMap { store.zones?.range(for: $0) }` is view-body code — no "TestStore/derivation test" can assert "chip range == zones.z1". Extract a pure helper the view calls (e.g. alongside `TodaySessionMode`, the existing pure test home in `SafetyRestComponentTests`) and test that. Also: no fixture exists for the scenario — all three tripped fixtures (`daily_brief_rest_*`) are `card: rest` with no `zoneTarget`, and `daily_brief_red` (the `active_recovery` + `z1` session) has `triggered: false` — so the test brief must be hand-rolled (`SafetyGate(triggered: true, overrideTo: .activeRecovery)` + `SessionBlock(card: .activeRecovery, zoneTarget: .z1, …)`); say so. → TASK-003.

7. **[low / apply]** `.syncFailed(SyncError)` is a distinct terminal (BriefViewState.swift:24) omitted from the rollover matrix — PLAN criterion 2 and TASK-001 tests name only `.checkInRequired`/`.error`. Covered for free by the stamp, but add it as a test argument so the closed gap is actually pinned. → TASK-001, PLAN criterion 2.

8. **[low / apply]** Risks claims "`briefState` flips off `.ready` in the same re-orchestration" — inaccurate: the flip happens in a *later* reducer turn (after async repo reads), so there's a ≥1-frame window rendering yesterday's `.ready` brief with the gauge/session card gutted (children nil'd). Previously that window showed the full stale content. Accept it explicitly in Risks (scene-activation timing hides it) or have `rolloverReset` also move `briefState`. → PLAN Risks.

9. **[low / defer]** Post-reset late child-save race: `CheckInComponent`'s save effect has no cancel ID; a save in flight across midnight resolves after the reset, restamps `lastSavedAt` (which TASK-002 explicitly exempts from the day-guard) and shows a fresh "Last saved" over the new-day gate for a check-in stored under yesterday's key, then triggers a new-day orchestration that correctly re-gates. Sub-second window, self-healing — note-only, not worth plan surface.

10. **[low / apply]** Two factual nits: TASK-001 says tests observe the stamp "after `.task`" — TodayFeature's trigger is `.onAppOpen` (sent by AppFeature; the view only sends `sceneBecameActive` via scenePhase). TASK-002's refactor note says snapshots are safe because "fixtures use today-dated existing" — actually the only check-in snapshot (`TodayViewSnapshotTests.test_checkIn`) seeds `lastSavedAt`, never `existing`; the conclusion (byte-identical PNGs) holds but the stated reason is wrong, and it strengthens the case for the pure `isSameSofiaDay(_:now:calendar:)` form over a view-time `\.date` read. → TASK-001, TASK-002.

**Internal coherence otherwise:** task deps sane (001/002/003 independent, 004 last); D1–D4 mutually consistent; D3's defense-in-depth is genuinely load-bearing (the child `.task`'s `._currentLoaded` can deliver yesterday's check-in *after* the reset — exactly the window the guard covers); acceptance criteria map 1:1 onto tasks (1–4→TASK-001, 5→TASK-002, 6→TASK-003, 7→TASK-004); hydrate-after-rollover test (e) is observable via `selectedIndex == 0` on the receive. RESEARCH's per-day inventory is correct except the `isBackgroundRefreshing` omission (finding 1).

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | `rolloverReset` must clear `isBackgroundRefreshing` (cancelled in-flight pass never clears it → stuck pill) | med | apply | Real stuck-UI hole. | TASK-001, PLAN.md:Acceptance, RESEARCH.md |
| 2 | Existing rollover test seeds no `contentDay` → breaks under the nil-must-not-trigger rule | med | apply | Update the seed; correct the "unchanged" claim. | TASK-001, PLAN.md:Acceptance |
| 3 | Effect factories can't mutate state — stamping mechanism must be specified (`inout State` factory signatures, 4 trigger sites) | med | apply | Prevents an invented internal action / scattered writes. | TASK-001 |
| 4 | Background-refresh straddling midnight desyncs the stamp from a hydrated next-day brief → spurious reset churn; D2 swaps server truth for a client stamp | med | apply | Stamp the background trigger sites too + D2/Risks notes. | TASK-001, DECISIONS.md:D2, PLAN.md:Risks |
| 5 | Guard shape must be explicit: staleness leg stays `.ready`-gated; in-flight `.syncing`/`.generating` DO participate in rollover | med | apply | Protects `test_sceneActive_nonReady_isNoOp`; overnight-suspended chain restarts safely via cancelInFlight. | TASK-001 |
| 6 | Chip derivation is view-body code — extract a pure helper + hand-rolled fixture (no existing fixture has triggered gate + activeRecovery + zoneTarget) | med | apply | Makes the headline acceptance observable. | TASK-003 |
| 7 | `.syncFailed` terminal missing from the rollover matrix | low | apply | Add as test argument. | TASK-001, PLAN.md:Acceptance |
| 8 | One-frame gutted-`.ready` render window before the async gate flip | low | apply | Accept explicitly in Risks (scene-activation timing hides it). | PLAN.md:Risks |
| 9 | Post-reset late child-save race (no cancel ID on the save effect; sub-second, self-healing) | low | defer | Note-only; not worth plan surface. | |
| 10 | `.onAppOpen` not `.task`; TASK-002's snapshot-safety reason wrong (fixture seeds `lastSavedAt`, not `existing`) | low | apply | Factual corrections. | TASK-001, TASK-002 |
