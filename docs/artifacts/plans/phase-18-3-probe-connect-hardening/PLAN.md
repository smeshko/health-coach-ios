# Plan: Onboarding-probe and Connect hardening

Status: done
Branch: fix/phase-18-3-probe-connect-hardening
Risk: medium
Epic: 18 — Make it run on device (audit wave 1) ([epic](../../epics/18-run-on-device.md))
Phase: 18.3 — Onboarding-probe and Connect hardening
Linear: none
Created: 2026-07-10

## Goal

Onboarding can no longer wedge or lie: the Connect probe is cancellable and distinguishes
"token rejected" from "server unreachable" (a stale/transient failure can't clear a newer
token or masquerade as invalid), and the priming presence probe runs under dedicated tight
bounds with the timeout path landing on an actionable degraded screen.

## Scope

- `ConnectComponent`: `CancelID.probe` + `cancelInFlight: true` on the connect effect; field
  edits (`binding`/`tokenPasted`) cancel any in-flight probe, so a stale probe response can
  never arrive after the user moved on — the "clears a newer valid token" race is closed
  structurally.
- Failure discrimination in `probeResponse(.failure)`: `APIError.unauthorized` → `.invalid`
  (token wrong — clear the candidate, as today); ANY other error (transport, timeout, the
  18.1 `.unconfigured` client) → new `Validation.unreachable` (server-side copy, candidate
  cleared for restore-safety but presented as reachability, not token rejection). This
  closes both carried 18.1 defers (config-failure presentation; "unconfigured looks like a
  bad token").
- `ConnectView`: render `.unreachable` with its own copy + tint (reuse the `.invalid` row
  structure); new snapshot recorded on the pinned sim.
- `HealthKitPriming`: probe with dedicated `HealthReadBounds.presenceProbe` (since
  `.distantPast`, `limitPerType: 365`, `timeout: .seconds(10)`) instead of the sync-default
  bounds; explicit test pinning that a probe `HealthKitReadError.timedOut` lands
  `.degraded(all rows)` with the Continue CTA — never a stuck `.checking`.

## Out of Scope

- Keeping an unvalidated candidate token stored on transport failure — a stored token flips
  the AppFeature launch restore to `.main`, so an unverified candidate must not persist
  (see Decisions).
- Launch token-restore discrimination (Keychain read error vs no token) — Phase 18.4.
- Retry/backoff for the probe — re-tap is the retry (single-owner app).
- Any change to the 18.2 read internals (`QueryLifecycle`/coordinator) — consumed as-is.

## Research Summary

See [RESEARCH.md](./RESEARCH.md). Load-bearing: the stale-probe race is real today — edits
during `.validating` reset the UI to `.idle` while the old probe keeps running; its late
failure then sets `.invalid` and `clear()`s whatever token is now stored. 18.2 already
bounded the priming probe (default bounds via `.since(.distantPast)`); a probe-timed-out
failure already lands in the existing `degradedProbeResponse(.failure)` → degrade-all arm,
so 18.3's priming work is dedicated bounds + an explicit timeout pin, not a new path.
`limitPerType` doubles as the activity-summary window in DAYS (18.2 review #2.2), so a
presence probe cannot use `limitPerType: 1` — activity would only read "present" with a
summary today.

## Decisions

- **Cancellation closes the race; discrimination fixes the message** — the epic's "stale
  probe failure must not clear a newer valid token" is solved structurally (cancelled
  effects can't deliver), not by token-matching bookkeeping in the failure arm.
- **Cancel arms also clear the candidate — as ONE cancellable effect under
  `CancelID.probe`** (validation round-1 #1 + round-2 #1) — cancelling suppresses the
  failure arm where the only `clear()` lives, so without the clear an edit-mid-probe
  leaves an unvalidated token in the Keychain (→ next launch restores to `.main`). The
  clear is itself registered under `CancelID.probe` with `cancelInFlight`, so the next
  `connectTapped` cancels a pending clear before writing — a detached clear could
  interleave write → clear → probe and 401 a valid token. Cancellation is COOPERATIVE
  (round-3 #1/#2/#3): the clear body leads with `Task.checkCancellation()`, the probe body
  checks before its write, and the failure-arm clears register under the same ID — the
  guard is best-effort; the residual window is one actor-hop racing a human re-tap,
  accepted. The final-validation task ticks the epic AC only after amending its wording to
  these cancellation+presentation semantics (round-1 #5).
- **Candidate still cleared on EVERY failure (unchanged DECISIONS-1 semantics)** — an
  unvalidated token left in the Keychain would make the next launch restore to `.main`
  (AppFeature only checks presence until 18.4). "Unreachable" is a presentation change,
  not a persistence change. The epic's "valid token survives a transient probe failure"
  is satisfied for the token that matters: a *newer* candidate can't be clobbered by a
  *stale* probe (cancellation), and a 401-valid stored token is never probed again on this
  screen.
- **`presenceProbe` bounds: `limitPerType: 365`, timeout 10s** — records/workouts need only
  1 newest row for presence (DESC sort), but the same field bounds the activity window in
  days; 365 keeps "old-but-granted reads present" true for a year of inactivity while
  staying firmly bounded. 10s < the sync default 15s: a probe is smaller than a delta read
  and the user is actively waiting on the onboarding screen.
- **`.unreachable` copy is fixed, not the thrown message** — consistent with the existing
  "no raw error strings in the feature" rule (ConnectView doc); the `.http` log carries the
  precise cause (18.1's always-on unconfigured diagnostic).

## Risks

- New `Validation` case ripples into view/state assertions — mitigated: exhaustive switch
  sites are few (ConnectView row + tint); TestStore tests updated alongside.
- Snapshot recording drift — record ONLY the new unreachable snapshot on the pinned sim
  (`make record-snapshots` scoped via SNAPSHOT_TARGETS; review PNG diff before commit).
- Cancelling on every keystroke could cancel a probe the user still wants — acceptable:
  edits invalidate the candidate by definition (the probe validates a token that is no
  longer what the field holds).

## Acceptance Criteria

- [x] A mid-probe edit cancels the in-flight probe AND clears the just-written candidate
  (the cancel-skips-clear persistence hole — validation round-1 #1): TestStore proves no
  `probeResponse` is delivered after `binding`/`tokenPasted` and `tokenClient.clear` was
  called. (`cancelInFlight: true` stays as untestable defense-in-depth — a concurrent
  second probe is unreachable through `canSubmit`; validation round-1 #2.)
  *(`test_editMidProbe_cancelsProbe_andClearsCandidate` +
  `test_retapAfterEdit_cancelsPendingClear_beforeWriting` passed 2026-07-10.)*
- [x] `probeResponse(.failure(APIError.unauthorized))` → `.invalid` + candidate cleared;
  any other failure (incl. `APIError.transport` from the 18.1 unconfigured client) →
  `.unreachable` + candidate cleared — unit-tested both arms; the two states render
  distinct copy (snapshot).
  *(`test_connect_unauthorized_clearsToken_showsInvalid_noConnected` +
  `test_connect_nonAuthFailure_clearsToken_showsUnreachable(probeError:)` [transport,
  decoding] passed; ConnectView snapshots green; sim run 2026-07-10: dead server →
  "Can't reach the server" copy, log shows `/probe` Connection refused.)*
- [x] The priming probe requests `HealthReadBounds.presenceProbe` (stub captures bounds:
  since == .distantPast, limitPerType == 365, timeout == 10s) and a probe `.timedOut`
  lands `.degraded(all rows)` with Continue enabled — never a stuck `.checking` (TestStore).
  *(`test_probe_requestsDedicatedPresenceProbeBounds` +
  `test_probeTimedOut_landsFullyDegraded_neverStuckChecking` passed; sim run 2026-07-10:
  healthd suspended mid-`.checking` → queries stopped at +10.5s → degraded screen.)*
- [x] Full suite + lint green; OnboardingFeature snapshots green with the one new
  unreachable snapshot case (a light+dark PNG pair — validation round-1 #3) recorded on
  the pinned sim; the copy lives in `ErrorDisplay.serverUnreachable` at the D19 boundary
  (validation round-1 #4).
  *(2026-07-10: 479 host tests / 95 suites passed; swiftlint --strict 0 violations in
  379 files; 94/94 snapshot tests passed on the pinned iPhone 17 Pro / OS 26.0.)*
- [ ] CI-pending (owner): on-device slow/failing-probe behaviour (wedged `healthd`,
  unreachable server) settles to actionable states — epic Validation.

## Tasks

Task state lives here. Tasks are appended by `scripts/add_task.py` and
`scripts/add_final_task.py`. Update the checkboxes as work progresses.

- [x] TASK-001: ConnectComponent: probe CancelID + 401-vs-transport discrimination
- [x] TASK-002: ConnectView: unreachable error presentation + snapshot (depends on TASK-001)
- [x] TASK-003: Priming presence-probe bounds + timeout-degrade pin (depends on TASK-001)
- [x] TASK-004: Final Validation
