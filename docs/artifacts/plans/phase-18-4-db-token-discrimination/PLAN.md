# Plan: Resilient-DB and token-restore discrimination

Status: in-progress
Branch: fix/phase-18-4-db-token-discrimination
Risk: medium
Epic: 18 — Make it run on device (audit wave 1) ([epic](../../epics/18-run-on-device.md))
Phase: 18.4 — Resilient-DB and token-restore discrimination
Linear: none
Created: 2026-07-10

## Goal

Failure ≠ corruption, and error ≠ absence: a transient/lockable DB-open failure no longer
wipes a healthy database (quarantine fires only on proven corruption, and moves the sidecars
that actually exist), and a thrown Keychain read at launch no longer strands a token-holding
owner at onboarding.

## Scope

- `DatabaseLive.makeLiveResilient`: replace the blanket `try?` with a do-catch +
  classification — only proven corruption result codes (`SQLITE_CORRUPT`, `SQLITE_NOTADB`)
  quarantine-and-recreate; every other failure (busy/locked, I/O, disk-full, cantopen, a
  throwing future migration, non-SQLite errors) PRESERVES the file and falls back to
  in-memory for this session (next launch retries the untouched file). Both paths logged
  distinctly on the always-on `.http` category (see Decisions).
- Quarantine moves the sidecars that actually exist: add `-journal` (DatabaseQueue runs in
  rollback-journal mode — the current list only covers WAL siblings).
- Injectable `open:` seam on `makeLiveResilient` so classification/recovery is unit-testable
  with forced errors; the existing corrupt-file integration test keeps passing.
- `AppFeature._restoreSession`/`_tokenChecked`: three-state restore
  (`present` / `absent` / `readFailed`) — `try?` no longer collapses a Keychain error into
  "no token". `readFailed` stays on `.main` (logged distinctly, cache-first open still
  dispatched); only a confirmed `absent` swaps to onboarding.
- `Package.swift`: `Database` target gains the `LogClient` dependency (18.2 precedent for
  Live-target logging).

## Out of Scope

- Retry/backoff loops on DB open or Keychain read — one classification, one fallback;
  relaunch is the retry (single-owner app).
- Any schema/migration content change; migration ERRORS are handled (preserve), not fixed.
- TokenClient live changes — `KeychainError.unexpectedStatus` already throws for
  non-notFound statuses; the fix is in the caller.
- Probe/Connect behaviour — shipped in 18.3.

## Research Summary

See [RESEARCH.md](./RESEARCH.md). Load-bearing: `makeLiveResilient` currently swallows the
open error entirely (`if let db = try? makeLive`), so a locked-but-healthy DB gets
quarantined — silent total data loss for a transient condition. `DatabaseQueue` (not Pool)
is the GRDB primitive in use → rollback-journal mode → `-journal` is the sidecar that
actually exists; the quarantine list only moves `-wal`/`-shm`. In AppFeature,
`try? tokenClient.read()` maps `KeychainError.unexpectedStatus` (e.g. keychain temporarily
unavailable) to `hasToken: false` → onboarding swap, exactly the audit's stranding case.

## Decisions

- **Only proven corruption quarantines; everything else preserves** — the corruption set is
  `resultCode` primary codes `SQLITE_CORRUPT` (11) and `SQLITE_NOTADB` (26). Busy/locked/
  I/O/full/cantopen and non-`DatabaseError` failures (migrations included) are conservative
  `preserve`: an in-memory session is a bounded cost; wiping a healthy DB is not. A
  permanently failing migration therefore means in-memory-until-fixed, loudly logged —
  never data destruction for a code bug.
- **In-memory fallback's session write-loss is explicit, not silent** (validation
  round-3 #1, slim arm) — a preserve-mode session accepts writes that vanish at exit; that
  is the PRE-EXISTING last-resort semantics (CR-2: every table is a re-derivable cache or
  re-enterable state), now strictly better because the on-disk data survives. The log
  record says "NEW WRITES WILL NOT PERSIST" outright. A read-only persistence state or a
  durable replay queue is real machinery for a rare transient on a single-owner app —
  DEFERRED (recorded as a known limitation / follow-up).
- **Injectable `open:` closure, not filesystem gymnastics, for tests** — forcing
  SQLITE_BUSY on a real file in a unit test is flaky; `makeLiveResilient(path:open:)` with
  the default `makeLive` keeps prod behaviour identical while tests inject
  `DatabaseError(resultCode:)` and assert quarantine vs preserve (file untouched).
- **`readFailed` stays on `.main`** — the default route is `.main`; staying put on a read
  ERROR is offline-safe and never strands a valid owner; swapping to onboarding on error
  would re-create the audit bug deliberately. Honest outcome spectrum (validation
  round-1 #3): transient failure → next request's per-call token read succeeds, business
  as usual; persistent failure → no request can be built (Transport reads the token before
  sending), so no 401 event fires — the user stays on `.main` with Today's existing
  sync-error surface + the always-on `.http` log naming the cause; relaunch is the
  recovery. Accepted for a single-owner app; comments must not claim the 401 stream covers
  the persistent case.
- **Decision/diagnostic log lines go on the always-on `.http` category** (validation
  round-1 #1) — `.app` is toggle-gated (off by default, unconditionally off in release),
  which would recreate the audit's "no trace" failure mode; 18.1 set the precedent
  (unconfigured-URL diagnostic, commit eec3e20). Messages carry path + result code only.
- **EPICS.md does not read `Done` while owner device criteria are open** (validation
  round-1 #2) — the last phase sets `Implemented — owner device validation pending`; the
  epic flips to Done only after the owner's physical-device run evidences the remaining
  boxes.
- **`_tokenChecked(hasToken: Bool)` becomes a three-case enum, not a second Bool** — the
  distinction IS the fix; encoding it as `(hasToken: Bool, failed: Bool)` invites the same
  collapse. Test ripple is two files (SwitchTests, ActionLoggingTests) and the TCA `.tca`
  action log stays payload-free (case label only).

## Risks

- GRDB `DatabaseError(resultCode:)` constructibility for tests — mitigated: it is public in
  GRDB 7; if a specific initializer is unavailable, throw it from the injected `open`
  closure via a tiny conforming error type asserting on `resultCode` classification instead.
- Corruption surfacing under a NON-corruption primary code (e.g. an extended IOERR while
  reading a corrupt page) — accepted: next launch retries and genuine corruption
  deterministically resurfaces as CORRUPT/NOTADB; the cost of a wrong `preserve` is one
  in-memory session, never data loss.
- `_tokenChecked` shape change ripples into log-format tests — enumerated in TASK-002.

## Acceptance Criteria

- [ ] Forced `SQLITE_BUSY`/migration-failure opens do NOT quarantine (file byte-identical
  after the attempt), fall back to in-memory, and log the preserve decision; forced
  `SQLITE_CORRUPT`/`SQLITE_NOTADB` (and the real garbage-bytes integration case) DO
  quarantine and recreate — unit + integration tested.
- [ ] Quarantine moves `-journal` alongside ``/`-wal`/`-shm` (test creates all four and
  asserts the `.corrupt` moves).
- [ ] A throwing `tokenClient.read()` at launch leaves the route on `.main` (TestStore) and
  logs the failure distinctly from "no token"; `absent` still swaps to onboarding; `present`
  unchanged.
- [ ] Full suite + lint green; no snapshot changes expected.
- [ ] CI-pending (owner): on-device — inject a transient DB failure / Keychain error and
  observe preservation + no forced onboarding (epic Validation; simulator smoke covers the
  in-app equivalents).

## Tasks

Task state lives here. Tasks are appended by `scripts/add_task.py` and
`scripts/add_final_task.py`. Update the checkboxes as work progresses.

- [x] TASK-001: DatabaseLive: corruption-vs-transient discrimination, journal sidecar, logged recovery
- [x] TASK-002: AppFeature: three-state token restore (present/absent/read-failed)
- [ ] TASK-003: Final Validation
