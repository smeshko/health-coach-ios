# Adversarial Validation — Round 3

**Run:** 2026-07-10
**Reviewer:** subagent (general-purpose — Codex usage-capped)
**Plan:** phase-19-3-day-rollover-state-reset
**Status at start:** draft
**Prior rounds in scope:** validation/round-1.md, validation/round-2.md

## Reviewer output

<!-- Subagent output verbatim below this line. Do not edit. -->

## Round-3 verdict

**Clean — the round-2 applies landed correctly and consistently; the behavioral consequence checks out in code. No med findings; three low notes, none blocking implementation.**

**Consistency sweep (TASK-001 ↔ D2 ↔ PLAN Risks ↔ acceptance):** no contradictions. The no-background-stamp rule is stated identically in all four places — TASK-001's "Do NOT stamp at the background trigger sites" paragraph, its acceptance bullet ("a pull does not move a stale stamp" — implementable: `backgroundRefreshEffect` stays non-`inout`), D2's "written ONLY by the `inout` effect factories… Background triggers do NOT stamp", and PLAN Risks bullet 2's correct-recovery reframe. The ~29-send sweep is named in both TASK-001 REFACTOR and PLAN criterion 3, and I verified it doesn't contradict acceptance (d)'s "staleness/throttle tests pass unchanged": `TodayFeatureSceneStalenessTests` sends only `sceneBecameActive` (lines 74/102/127/188) — no stamping trigger actions — and the same-day tests seed a nil stamp, which the nil-must-not-trigger rule lets fall through to the unchanged staleness leg. The two doc-comment updates are named (round-2 #3 applied).

**Behavioral consequence — confirmed from code:**
1. **The stale-stamp pull scenario is real as framed.** `pullToRefresh` is `.ready`-gated only (TodayFeature.swift:209); at 00:01 `runBackgroundPass` → `dailyBrief(refresh: true)` returns today's brief → `._backgroundRefreshResolved` fails `contentEquals` → `hydrate` → `.ready(today, .fresh)` — seeding the carousel from yesterday's in-memory pick (TodayOrchestration.swift:129) with the check-in child's yesterday `existing` intact. Stamp stays yesterday. Exactly the state the next-activation reset must wipe.
2. **Re-gating happens.** The rollover branch's `cacheFirstOpenEffect` runs the check-in gate FIRST, before the cache peek (TodayOrchestration.swift:62–67), and `CheckInRepositoryLive.current` fetches by Sofia `startOfDay` PK (`CheckInRecord.fetchOne(db, key: day)`, CheckInRepositoryLive.swift:28–31) — a new day reads `nil` → `._checkInRequired`. Today's cached brief cannot short-circuit the gate.
3. **No loop.** The `inout` factory stamps `contentDay = today` synchronously in the rollover reducer turn, so every subsequent activation takes the same-day path; over the resulting `.checkInRequired`, the staleness leg is `.ready`-gated → no-op. Post-save, `orchestrationEffect` re-stamps today. TASK-001's acceptance ("asserted… after rollover re-orchestration") pins this. Ratchet is one-way; no reset ping-pong.

## Findings

1. **[low / apply-if-touching]** TASK-001's staleness-leg justification is imprecise: "(it only runs when the rollover leg already found `contentDay == today`)" — the leg also runs with `contentDay == nil` (fall-through), which is precisely what keeps the three nil-stamp same-day staleness tests green (the plan's own "other scene tests survive a nil stamp" claim depends on it). If an implementer literalizes the parenthetical into a `contentDay == today` guard on the staleness leg, those existing tests break. The unambiguous spec statements elsewhere ("stays `.ready`-gated exactly as today", "nil must NOT trigger") outweigh it; a one-clause "(== today or nil)" fix suffices.
2. **[low / note]** The existing rollover test edit is slightly under-specified: besides the `contentDay: yesterday` seed, `test_sceneActive_dayRollover_reOrchestrates_hitsCheckInGate`'s exhaustive `store.send(.sceneBecameActive)` (currently no trailing closure, SceneStalenessTests:127) will now also need `{ $0.contentDay = today }` — the rollover branch stamps via the `inout` factory. It's outside the "~29 sends across ~5 files" sweep (SceneStalenessTests isn't among them). Exhaustivity failure makes it self-announcing; the sweep note primes for the pattern.
3. **[low / cosmetic]** The round-2 #3 doc-comment bullet was filed under the TodayOrchestration.swift Files bullet, but both comments live in TodayFeature.swift (:104–105 and :216–217). The quotes make them findable; misfiled, not wrong.

**Note-only (no plan surface, mirrors the round-1 #9 treatment):** after the rollover stamp, there is a milliseconds-wide window (one local gate read) where state is still `.ready` with `contentDay == today`; a second activation or pull landing inside it would `cancelInFlight` the re-gating open and skip the gate until relaunch. Requires two user-visible scene transitions within one DB read — not realistic, and PLAN Risks already accepts the transient stale-`.ready` shell.

The plan is ready for implementation as written.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Staleness-leg parenthetical could be literalized into a test-breaking `== today` guard | low | apply | One-clause fix ("== today or nil") + explicit do-not-literalize note. | TASK-001 |
| 2 | Existing rollover test also needs a `$0.contentDay = today` trailing-closure assert (outside the named sweep) | low | reject (note) | Self-announcing via TestStore exhaustivity; the sweep note primes the pattern. | |
| 3 | Doc-comment bullet misfiled under the wrong Files entry | low | apply | Folded into the same TASK-001 edit (file named explicitly). | TASK-001 |
