# Decisions: Day-rollover state reset (Phase 19.3)

## D1 — Reset at the detection point, not scattered through gate actions

**Options weighed:**
1. **A single `rolloverReset(&state)` mutation invoked where rollover is detected**
   (the `sceneBecameActive` rollover branch), before returning
   `cacheFirstOpenEffect()`.
2. **Reset piecemeal inside the downstream actions** (`._checkInRequired` clears the
   check-in child, `hydrate` ignores stale picks by comparing days, etc.).

**Chosen: 1.** One mutation with an explicit "per-day state" contract is auditable and
testable as a unit; option 2 spreads day-awareness across actions that are also reached
same-day (e.g. `._checkInRequired` after a same-day reset-token flow must NOT clear a
just-typed answer set), inviting exactly the class of bug this phase fixes. The
downstream actions stay day-blind; only the detector knows about days.

## D2 — `contentDay` stamp to close the non-`.ready` rollover gap

**Options weighed:**
1. **Stamp `state.contentDay` (Sofia `startOfDay`) at orchestration entry**, and let
   `sceneBecameActive` compare it for ALL terminal states (`.ready` keeps working via
   the same stamp; `.checkInRequired`/`.error` become rollover-detectable).
2. **Keep the `.ready`-only guard** and accept that yesterday's `.checkInRequired`/
   `.error` survive midnight (self-heals only on relaunch).
3. **Derive the day from state** (`.ready` → `brief.date`; `.checkInRequired` →
   `checkIn.existing?.date`; `.error` → nothing) — no new state, but `.error` stays
   undetectable and `.checkInRequired`'s derivation is wrong when no check-in exists.

**Chosen: 1.** The epic's acceptance is "crossing midnight resets the gate" without
qualifying which terminal state yesterday ended in; option 3 cannot detect the `.error`
day and misdetects an unanswered `.checkInRequired`. The stamp is written ONLY by the
`inout` effect factories (one conceptual write point; their four reducer trigger sites
inherit it) and read by one detector. Background triggers (`pullToRefresh`, the
staleness leg) do NOT stamp — round-2 #1 reversed round-1 #4's mitigation:
`pullToRefresh` is `.ready`-gated but not same-day-gated, so stamping there at 00:01
would write `contentDay = today` over yesterday's un-reset children and permanently
mask the rollover. A cross-midnight background pass that hydrates a next-day brief
while the stamp stays yesterday is the *correct recovery*: the next activation resets
and re-gates (new day ⇒ new check-in; today's persisted pick survives via
`_selectionLoaded`). `.ready`'s existing `brief.date` comparison is replaced by the
same stamp so there is one detector, not two. **Deliberate semantic change**
(round-1 #4): the detector now trusts the client-side stamp of "when orchestration
last ran" rather than the server's `brief.date` — that is the point (non-`.ready`
states have no server date).

## D3 — Footer day-guard as defense in depth (kept despite the reset)

With D1's reset, the stale footer cannot render via the resident-across-midnight path.
The day-guard on "Saved earlier today" (`existing.date` is today, Sofia) is kept anyway:
the child's `.task` reload and the parent reset are side effects that can be delayed or
missed (the audit's core criticism), and the guard makes the *render* honest
unconditionally. One `calendar.isDate(_:inSameDayAs:)` in the view/component, one test.

## D4 — `Zones.range(for:)` as an internal TodayFeature extension, not DomainModels API

Both call sites (`SessionFeature.State.zoneRange(for:)` and the forced-REST branch in
`TodayReadyContent`) live in the TodayFeature module. Promoting the switch to
`DomainModels` is the SSOT consolidation Epic 20 Phase 20.1 explicitly owns (this epic
fixes divergence, wave 3 dedups); an internal extension removes the duplication *within*
the module without widening public API. `SessionFeature.State.zoneRange(for:)` delegates
to it (behavior pinned by existing `SessionFeatureTests`).
