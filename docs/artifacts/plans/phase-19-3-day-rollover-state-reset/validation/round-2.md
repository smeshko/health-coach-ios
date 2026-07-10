# Adversarial Validation — Round 2

**Run:** 2026-07-10
**Reviewer:** subagent (general-purpose — Codex usage-capped)
**Plan:** phase-19-3-day-rollover-state-reset
**Status at start:** draft
**Prior rounds in scope:** validation/round-1.md

## Reviewer output

<!-- Subagent output verbatim below this line. Do not edit. -->

## Round-2 verdict

**Round-1 applies: all 9 landed in the right files and say the right things** — I verified each against the plan text and the code (`isBackgroundRefreshing` in the reset contract + RESEARCH:28 + criterion 1; the existing-test `contentDay` seed note; the `inout` mechanism; the guard-shape paragraph; `.syncFailed` parameterization; the accepted one-frame Risks line; `.onAppOpen`/snapshot-reason corrections). The **#9 defer is correct** — I re-checked `CheckInComponent`: the save effect has no cancel ID, but a cross-midnight `saveResponse(.success)` fires the delegate → `orchestrationEffect(refresh: true)` → stamps today → gate check reads today's key → `nil` → re-gates. Self-healing exactly as triaged; no plan surface needed.

**But two of the applies introduced new problems, one of them load-bearing.** The other scrutinized edits check out: `pullToRefresh` exists (TodayFeature.swift:103/206); the widened `.syncing`/`.generating` rollover guard is safe because `test_sceneActive_nonReady_isNoOp` (SceneStalenessTests:180–190) iterates all four non-ready states with a **nil** stamp, which the nil-must-not-trigger rule preserves — no test pins "activation over `.syncing` is a no-op" for a *stamped-stale* state; `.syncFailed` is a genuine resident overnight terminal (BriefViewState.swift:14 — "distinct terminals", a Retry screen the user can park on), and the parameterized test needs no per-case variation (all three receive the same `._checkInRequired`). TASK-004 still covers criterion 7 (full suite + snapshots) with 1–6 mapped to TASK-001/002/003.

## Findings

**1. [med / apply] Round-1 #4's chosen mitigation is inverted — stamping at the background trigger sites reintroduces the bug this phase fixes.** TASK-001's premise "they are same-day by construction" is false for `pullToRefresh`: its guard is `.ready`-only (TodayFeature.swift:209), not same-day — a pull at 00:01 with the app resident since yesterday stamps `contentDay = today` over yesterday's children. If the pass then hydrates today's brief, `hydrate` seeds the carousel from `state.session?.selectedSession` (yesterday's pick, TodayOrchestration.swift:129) and the check-in child keeps yesterday's `existing` — with the stamp now reading *today*, the next `sceneBecameActive` sees no rollover and the reset/gate never runs until relaunch. If the pass *fails*, it's worse: stamp=today, content=yesterday, rollover permanently masked. Meanwhile on the staleness leg stamping is a provable no-op (that leg only runs after the rollover leg found `contentDay == today`). The "spurious reset churn" #4 feared is actually the **correct recovery**: a cross-midnight pass that hydrated a next-day brief *should* reset children and re-gate on the next activation (new day ⇒ new check-in; today's persisted pick survives via `_selectionLoaded`). Apply: drop the background-site stamping; `contentDay` is written **only** by the four gated `inout` entry factories; take round-1 #4's own offered alternative (accepted-churn line in Risks, reframed as correct recovery). Targets: `tasks/TASK-001...md` (the "ALSO stamp" paragraph + the "asserted after `pullToRefresh`" acceptance bullet), `DECISIONS.md` D2 (last two sentences), `PLAN.md` Risks bullet 2.

**2. [med / apply] The `inout`-stamping apply (#3) has an unstated exhaustive-TestStore ripple that contradicts TASK-001's own claim.** TASK-001's REFACTOR says existing tests "must not need edits beyond additive defaults" — false: ~29 `store.send(.onAppOpen/.retryTapped/…)` calls across 5 files (CacheFirst, Orchestration, Save, SelectionRestore, BackgroundDegrade) are exhaustive sends whose trailing closures don't assert the new `contentDay` mutation; every one fails with "state was not expected to change" and needs a mechanical `$0.contentDay = <today>` line. The plan forbids the escape hatch (an internal stamping action — correctly, per round-1 #3), so the sweep is unavoidable and must be named or the implementer will misread RED noise as a design bug. Targets: `tasks/TASK-001...md` (REFACTOR bullet + Notes), `PLAN.md` criterion 3 ("existing tests pass" → "pass after the mechanical `contentDay`-assert sweep on trigger sends").

**3. [low / apply] Two doc comments become lies under the widened guard.** `Action.sceneBecameActive`'s comment ("from `.ready` only", TodayFeature.swift:104–105) and the reducer branch comment ("non-ready states are already showing the right thing", :216–217) both encode the old contract; the repo treats these lifecycle comments as load-bearing. One Files-bullet line in `tasks/TASK-001...md` ("update the action + branch comments to the contentDay contract").

**Mechanically, the `inout` refactor itself is coherent**: all four factory call sites (TodayFeature.swift:199, 204, 223, 364) sit inside the `Reduce` closure where `state` is `inout`, the factories' `.run` closures capture only explicit deps (no escape of the `inout` param), and `State.init` gains a defaulted `contentDay:` param additively. No finding there beyond #2's test ripple.

No further findings — TASK-002 (footer branch verified at CheckInSection.swift, `else if store.existing != nil`) and TASK-003 (hardcode + "reconciled when that lands" comment verified at TodayReadyContent.swift:57–64; `TodaySessionMode` pure-test home confirmed in SafetyRestComponentTests) are implementable as written.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Background-site stamping (round-1 #4 mitigation) inverts the fix — a 00:01 pull masks rollover permanently; the feared churn is the correct recovery | med | apply | Dropped background stamping; stamp = the four gated `inout` factories only; Risks reframed. | TASK-001, DECISIONS.md:D2, PLAN.md:Risks |
| 2 | ~29 exhaustive trigger-sends across ~5 test files need a mechanical `$0.contentDay` assert — contradicted TASK-001's "no edits" claim | med | apply | Named the sweep so RED noise isn't misread as a design bug. | TASK-001, PLAN.md:Acceptance |
| 3 | Two lifecycle doc comments encode the old `.ready`-only contract | low | apply | Update both to the contentDay contract. | TASK-001 |
