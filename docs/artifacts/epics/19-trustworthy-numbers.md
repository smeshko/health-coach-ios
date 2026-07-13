# Epic 19 — Make the numbers trustworthy (audit wave 2)

Status: planned
Created: 2026-07-05
Depends on: Epic 18
Project: audit-remediation-2026-07
Linear: none
Milestone: none

## Overview

Second remediation wave: close the correctness and data-integrity holes that make
the app show plausible-but-wrong coaching data with no signal. The Domain
Correctness lens returned NO-GO because the chain breaks at independent load-bearing
points — iOS HealthKit ingest drops or mislabels the inputs readiness depends on,
the profile cache never refreshes so recomputed zones stay stale, undecodable
cached rows brick a whole period, day rollover carries yesterday's answers into
today's gate, and two backend "deterministic" invariants are wired to no-ops so
periodization silently never fires. This epic makes the numbers — readiness, zones,
targets, the weekly plan's alternation — actually reflect the athlete. Depends on
Epic 18 so each fix is demonstrable on device.

## Architecture references

- [docs/ARCHITECTURE.md](../../ARCHITECTURE.md) — iOS Clients/Repositories layers,
  cache-first policy, day-boundary (Sofia day) rules.
- [../../../backend/docs/architecture/LLM.md](../../../backend/docs/architecture/LLM.md)
  and [MODELS.md](../../../backend/docs/architecture/MODELS.md) — the deterministic
  engine vs LLM split and the periodization invariants being repaired.
- [docs/artifacts/audits/AUDIT-2026-07-05.md](../audits/AUDIT-2026-07-05.md) —
  Domain Correctness lens verdict and the per-finding evidence.

## Dependencies

- **Epic 18** — device reachability and bounded reads, so correctness fixes can be
  demonstrated at runtime rather than only in tests.

## Out of scope

- SSOT consolidation of the client-side readiness band / enum maps — Epic 20
  Phase 20.1 (this epic fixes correctness where a duplicate has *diverged*; the
  dedup itself is wave 3).
- Weekly-tab reliability (cache-first honor, refresh) — Epic 20 Phase 20.3.

## Phase 19.1 — HealthKit ingest correctness

**Plan**: [phase-19-1-healthkit-ingest-correctness](../plans/phase-19-1-healthkit-ingest-correctness/PLAN.md) · status: done

**Linear**: none

**Goal**: Fix the watermark, distance, effort, and workout-type mapping so ingested samples are complete and correctly typed.

### What to build

- Fix the delta watermark in `Sources/Clients/HealthKitClient/Live/HKDeltaReads.swift`:
  the query filters by sample `startDate` while the sync watermark records wall-clock
  read time, so late-arriving Watch sleep/HRV/RHR are permanently dropped. Move to
  anchored-query semantics (or a watermark that captures late arrivals).
- In `Sources/Clients/HealthKitClient/Live/HKSampleMapping.swift`: read distance
  across modalities (cycling/swimming/rowing), not only `distanceWalkingRunning`;
  source effort from where Apple actually stores it (not
  `metadata["HKWorkoutEffortScore"]`); and send `Workout.type` as the name string
  the contract/fixtures expect, not the numeric `HKWorkoutActivityType` raw value.

### Acceptance criteria

- [x] A sleep/HRV/RHR sample written after the watermark is still ingested on the
  next sync (no permanent drop). *(48h lookback on the delta-read floor, pinned by
  `SyncBoundedReadTests` — sim green 2026-07-10.)*
- [x] A cycling/swimming/rowing workout syncs a non-nil `distanceM`.
  *(`HKDistanceCandidatesTests` per-modality fixtures.)*
- [x] `Workout.type` on the wire matches the backend's expected name-string contract.
  *(`HKActivityTypeNameTests` pins exact snake_case wire strings, never numeric.)*
- [x] Effort is populated when the platform provides it (or the field is honestly
  absent, not read from the wrong key). *(Effort-relationship samples, user-logged >
  estimated, honest nil — `HKEffortScoreTests` + `HKReadSetCoverageTests`; the
  metadata read is gone.)*

### Validation

Seed workouts of multiple modalities and a late-arriving overnight sample; show the
synced payload contains distances, correct type strings, and the late sample.

---

## Phase 19.2 — Cache invalidation and graceful degradation

**Plan**: [phase-19-2-cache-invalidation-graceful-degradation](../plans/phase-19-2-cache-invalidation-graceful-degradation/PLAN.md) · status: done

**Linear**: none

**Goal**: Invalidate the profile cache on recompute and degrade undecodable cached rows to a miss instead of bricking the period.

### What to build

- In `Sources/Repositories/ProfileRepository/Live/ProfileRepository+Live.swift`,
  implement the documented-but-missing invalidation so a server constants recompute
  causes a refetch (recomputed HR zones/thresholds reach the device); and make an
  undecodable cached profile body degrade to a fetch, not a permanent brick.
- In `Sources/Repositories/BriefRepository/Live/DailyBriefPolicy.swift` and
  `WeeklyPlanPolicy.swift`, treat a decode failure in the non-refresh cache branch
  as a cache *miss* (regenerate) rather than propagating and bricking the whole
  Sofia-day / ISO-week period.

### Acceptance criteria

- [x] After a constants recompute, `profile()`/`zones()` return the new values
  without a reinstall. *(Satisfied as: new values visible at the next successful
  sync — the profile row is stamped with the watermark `serverTime` and refetches
  once per sync advance (D1 sync-anchored staleness, no TTL/no new wire fields);
  `ProfileCacheTests` pin refetch-restamp-steady-state — sim green 2026-07-10.)*
- [x] An undecodable cached brief/plan/profile row degrades to a fresh fetch, and
  the user is never stuck with an unrecoverable Retry. *(Decode failure = cache
  miss for daily/weekly (regenerate overwrites the PK; sync-gated path surfaces
  recoverable `.syncRequired`), peek returns `nil`, profile deletes the row and
  refetches — worst case is the ordinary `fetchFailed`, never a `DecodingError`
  brick; each degradation logs one `.http` notice.)*

### Validation

Corrupt/format-drift a cached row and trigger a recompute; show the app refetches
and renders current data instead of an empty/failed screen.

---

## Phase 19.3 — Day-rollover state reset

**Plan**: [phase-19-3-day-rollover-state-reset](../plans/phase-19-3-day-rollover-state-reset/PLAN.md) · status: done

**Linear**: none

**Goal**: Reset per-day child state on day rollover so yesterday's check-in and pick don't seed today, and resolve the forced-REST zone chip.

### What to build

- In `Sources/Features/TodayFeature/Sources/TodayFeature.swift` (and
  `TodayOrchestration.swift`), reset per-day child state on Sofia-day rollover so
  the new day's check-in gate does not show yesterday's answers as already saved,
  and yesterday's workout pick cannot seed today's carousel.
- In `Sources/Features/TodayFeature/Sources/CheckInComponent.swift`, clear the
  stale "Last saved" footer/answers on rollover.
- In `Sources/Features/TodayFeature/Sources/TodayReadyContent.swift`, resolve the
  forced-REST override card's zone chip (currently the stale "when that lands" gap).

### Acceptance criteria

- [x] Crossing midnight (Sofia) resets the check-in gate to unanswered and clears
  the "Last saved" footer. *(Rollover reset at the `sceneBecameActive` detector over
  any `contentDay`-stamped state; footer additionally day-guarded via
  `isSameSofiaDay` — `TodayFeatureRolloverResetTests` + `CheckInComponentTests`
  boundary cases, sim green 2026-07-10.)*
- [x] Yesterday's workout pick does not pre-seed today's carousel. *(Reset nils
  `session`/`restoredSelection`; hydrate-after-rollover falls to the primary unless
  today's own persisted pick exists — `test_dayRollover_hydrate_prefersPrimary_
  noStalePickSeed` / `_todaysPersistedPick_seedsCarousel`.)*
- [x] The forced-REST card renders a resolved zone chip, not a placeholder.
  *(`zoneRange: nil` hardcode replaced by `TodaySessionMode.overrideZoneRange`
  resolving `zoneTarget` from loaded zones via the shared `Zones.range(for:)` —
  `SafetyRestComponentTests` chip triple; SafetyRest snapshots byte-identical.)*

### Validation

Advance the clock across a Sofia midnight with the app resident; show the check-in
gate and carousel reset, and the forced-REST chip resolved.

---

## Phase 19.4 — Backend deterministic-invariant repair ✅ DONE

**Plan**: (backend repo) `docs/artifacts/plans/archive/2026-07-13-phase-19-4-deterministic-invariant-repair` · status: done · **PR smeshko/health-coach-be#45**

**Linear**: none

**Goal**: Make the threshold-vs-VO2 weekly alternation and monthly zone re-derivation actually fire instead of no-op.

### What to build

- In `app/core/weekly_planner.py` and `app/services/recompute.py`: `_last_quality_focus()`
  hardcodes `return None`, so `next_quality_focus` always returns THRESHOLD and the
  threshold↔VO₂ alternation never flips; feed it the real last focus and drive it
  weekly, not monthly.
- Fix `rederive_zones` so its sole caller passes the *new* anchors (not the current
  ones), and remove/repair the unconditionally-dead zone-rederivation branch in
  `RecomputeConstants` (`new == current` always).

### Acceptance criteria

- [x] Consecutive weekly plans alternate quality focus between threshold and VO₂
  as designed. *(Computed every week in `RecomputeConstants` off the prior ISO-week's
  persisted `plans.inputs_snapshot["quality_focus"]` — DB-transactional (refresh reads
  W-1, no double-flip), legacy/malformed-row-safe, canonical ISO-week keys. Both validator
  + agent readers agree on a not-due week. Failing-then-passing in
  `tests/core/test_weekly_planner.py`.)*
- [x] A changed anchor actually re-derives HR zones (the rederive branch is
  reachable and correct). *(Made **correct-when-reachable**: an anchor move now updates
  `thresholds.max_hr`/`rhr_baseline` atomically with `zones` — the validator would reject
  a zone-only write — and an inadmissible anchor falls back to current zones rather than
  aborting generation. Demonstrated via an injected anchor. **The runtime measured-max-HR
  SOURCE has no safe in-pipeline origin** (`compute_zones` is %-of-max-HR only; the profile
  validator forces zones to match the stored anchor), so building it is deferred to the new
  **Phase 19.6** — see below.)*

### Validation

Backend tests over consecutive weeks assert the quality focus alternates; a changed
anchor produces re-derived zones. Failing-then-passing shown; full suite green + ruff
clean. **3 rounds pre-implementation validation** (killed the original premise → the
DB-focus + 19.6-defer redesign) + **3 rounds post-implementation review**.

---

## Phase 19.5 — Backend persistence integrity ✅ DONE

**Plan**: (backend repo) `docs/artifacts/plans/archive/2026-07-13-phase-19-5-persistence-integrity` · status: done · **PR smeshko/health-coach-be#46**

**Linear**: none

**Goal**: Persist the readiness snapshot reliably, retry the profile.yaml write, and index workouts by start_date.

### What to build

- In `app/core/daily_adjuster.py`, stop silently losing the readiness/band snapshot
  when no `daily_metrics` row exists for the brief day — ensure the row is created
  (or the snapshot is otherwise persisted) so the write in the bare `UPDATE` lands.
- In `app/api/routes/weekly.py`, retry (or transactionally guard) the post-commit
  `profile.yaml` write so a failure doesn't leave the cached plan permanently
  diverged from its constants.
- In `app/database/models/workouts.py`, add an index on `start_date` (every hot
  query filters workouts by date range).

### Acceptance criteria

- [x] A brief requested before the day is synced still persists its readiness
  snapshot (no silent drop). *(Bare UPDATE → sqlite `on_conflict_do_update` on the `date`
  PK; the row is created carrying the verdict. Review also fixed a coverage bug this
  introduced: `n_days` now counts `COUNT(computed_at)` so the placeholder doesn't inflate
  weekly-planner coverage.)*
- [x] A failed `profile.yaml` write is retried/recovered so plan and constants stay
  consistent. *(Bounded retry recovers transient failures; on exhaustion the committed
  plan is **invalidated** so the next request regenerates + re-writes rather than serving a
  cache hit with stale constants. **Deploy follow-up:** a container redeploy can lose a
  successful write — profile.yaml is baked in the ephemeral `/app` layer, not on durable
  `/data` — documented in backend `RUNBOOK.md §5`; move `PROFILE_PATH` to `/data` (candidate
  Phase 19.7). Concurrency findings are N/A for the single-user deployment.)*
- [x] `workouts.start_date` is indexed; date-range queries use it. *(`Index(None,
  "start_date")` + migration `0005`; `compare_metadata` clean.)*

### Validation

Backend tests: unsynced-day snapshot persists; transient write retried + persistent write
invalidates→recovers; migration `0005` index present with metadata parity. 1333 tests +
ruff green. **3 rounds post-implementation review** (caught the coverage bug + reopened the
profile-write divergence).

---

## Phase 19.6 — Runtime measured max-HR anchor source (follow-up, NOT STARTED)

**Plan**: _not yet created_

**Linear**: none

**Goal**: Give Phase 19.4's correct-when-reachable zone-rederivation branch a real anchor —
derive the athlete's measured max-HR at recompute time so a genuine anchor shift re-derives HR
zones in production (not only under an injected test anchor).

### Why it's separate (from 19.4 validation)

`compute_zones` is %-of-max-HR only (RHR moves no bound) and the profile validator forces
`zones.z5.high == thresholds.max_hr`, so the zone branch can fire only on a **measured** max-HR
differing from the stored anchor. No such runtime source exists — `daily_metrics` has no
`max_hr` column; only the offline `scripts/derive_constants.py:derive_max_hr` (whole-corpus
bounded MAX over `records`) derives it. A safe runtime version is **whole-corpus + ratchet-up
only + dual type-alias (`HeartRate` id vs live `heart_rate` wire) + tz-safe** — net-new work
with real zone-corruption risk (max-HR drives *every* bound), so it was split out of 19.4.

### What to build

- A runtime `measured_max_hr(session, as_of)` (SQLAlchemy port of the offline derivation:
  whole-corpus bounded MAX, ratchet-up only so a quiet window can't lower the anchor, both
  stored type aliases, tz-safe bounds), feeding `RecomputeConstants`'s `rederive_zones` call in
  place of the current `new == current` no-op. The merge is already correct-when-reachable (19.4).

### Acceptance criteria

- [ ] A real measured max-HR shift (from `records`) re-derives HR zones end-to-end in the
  weekly recompute; a quiet window or sensor artifact does not move the anchor.

---

<!-- PHASES -->

## Epic-level acceptance criteria

- [~] Readiness, zones, targets, and the weekly plan's periodization reflect the
  athlete's real inputs end-to-end (HealthKit → backend → iOS render), demonstrated
  on device. *(Readiness, targets, day-rollover, ingest, and the weekly **quality-focus
  periodization** now reflect real inputs. **Two residuals:** the **zone re-derivation
  runtime source** is deferred to Phase 19.6 (no safe in-pipeline measured max-HR — see
  19.4/19.6); and **on-device demonstration is owner-only** (needs the phone + prod backend,
  as with Epic 18).)*
- [x] Every phase merged and its acceptance criteria met *(19.1–19.5 all merged with criteria
  met; 19.4's zone-source half + 19.5's redeploy-durability were split into follow-ups
  **19.6**/**19.7** rather than left silently incomplete.)*
- [x] Status row in [EPICS.md](./EPICS.md) updated *(→ "Implemented — 19.6 zone-source
  follow-up + owner device validation pending".)*

**Epic status:** the five originally-scoped phases (19.1–19.5) are **shipped**. The epic
surfaced one real scoping discovery — there is no safe runtime measured-max-HR source, so the
zone-rederivation branch is correct-when-reachable but not yet production-live — carried as
**Phase 19.6**. A profile.yaml redeploy-durability hardening is carried as a **19.7** candidate
(backend `RUNBOOK.md §5`). On-device end-to-end demonstration is owner-only.
