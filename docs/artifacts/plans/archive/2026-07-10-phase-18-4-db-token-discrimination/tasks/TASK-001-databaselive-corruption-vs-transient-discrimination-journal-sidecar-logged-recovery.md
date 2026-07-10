# TASK-001: DatabaseLive: corruption-vs-transient discrimination, journal sidecar, logged recovery

Depends on: None
Suggested commit: `fix(database): quarantine only on proven corruption; move -journal sidecar`

## Goal

A transient/lockable open failure can never wipe a healthy database: only proven corruption
result codes quarantine, everything else preserves the file and degrades to an in-memory
session — both logged distinctly.

## Files

- `Sources/Clients/Database/Sources/DatabaseLive.swift` —
  - `enum OpenFailureRecovery: Equatable { case quarantine, preserve }` +
    `static func classifyOpenFailure(_ error: Error) -> OpenFailureRecovery` — pure:
    `DatabaseError` with primary `resultCode` `.SQLITE_CORRUPT` or `.SQLITE_NOTADB` →
    `.quarantine`; EVERYTHING else (busy/locked/ioerr/full/cantopen, non-DatabaseError,
    migration throws) → `.preserve`.
  - `makeLiveResilient(path:open:)` — do-catch (no `try?`), injectable
    `open: (String) throws -> DatabaseClient = { try makeLive(path: $0) }`:
    `.quarantine` → quarantine + one recreate attempt (open failure there → in-memory);
    `.preserve` → in-memory WITHOUT touching the disk file. THREE distinct outcome
    records on the ALWAYS-ON `.http` category (validation round-1 #1 + round-3 #2 — `.app`
    is toggle-gated; same fix as 18.1's eec3e20):
    - preserve: `"DB open failed (transient <code>) — file preserved, in-memory this
      session; NEW WRITES WILL NOT PERSIST"` (the write-loss trade is explicit —
      round-3 #1);
    - quarantine + recreate SUCCESS: `"DB corrupt (<code>) — quarantined, recreated"`;
    - quarantine + recreate FAILURE: `"DB corrupt (<code>) — quarantined, recreate FAILED
      (<code2>), in-memory this session"` — never log "recreated" when the second open
      failed (round-3 #2).
    No user data in messages (path + result codes only).
  - `quarantineDatabaseFile` suffixes: `["", "-journal", "-wal", "-shm"]` — DatabaseQueue
    runs rollback-journal mode, `-journal` is the sidecar that actually exists.
- `Package.swift` — `Database` target gains `"LogClient"` (18.2 precedent).
- `Sources/Clients/Database/Tests/MakeLiveTests.swift` —
  - classifier unit tests: CORRUPT/NOTADB → quarantine; BUSY/LOCKED/IOERR/FULL/CANTOPEN +
    a plain `struct SomeError: Error` (the migration-bug stand-in) → preserve. Construct
    via `DatabaseError(resultCode:)` if public in GRDB 7; else classify through the
    injected `open` throwing a wrapper (PLAN Risks fallback).
  - preserve integration: healthy on-disk DB + injected BUSY-throwing `open` →
    `makeLiveResilient` returns a working (in-memory) client, the on-disk file is
    BYTE-IDENTICAL after (hash before/after), and NO `.corrupt` file appears.
  - quarantine integration: existing garbage-bytes test keeps passing; extend to create
    `-journal`/`-wal`/`-shm` siblings and assert all four `.corrupt` moves.
  - log-capture tests (validation round-2 #2 + round-3 #2): ALL THREE recovery outcomes
    emit their record on `.http` — capture the call-site record (inject a recording log
    value via `withDependencies`), assert category == `.http`, the classification +
    result code(s) in the message, and no raw error payloads. Includes a STATEFUL
    injected-open test: first call throws CORRUPT, the post-quarantine call throws BUSY →
    assert the recreate-FAILURE record and the in-memory fallback (never a false
    "recreated"). Add the LogClient test-support dependency to the Database TEST target in
    `Package.swift` as needed. (The existing LogClientLive all-settings-off test remains
    the release-gate proof that `.http` always emits.)

## Acceptance

- [ ] Classifier matrix pinned (corruption → quarantine; 5 transient codes + non-SQLite →
  preserve).
- [ ] Preserve path: file untouched (hash), no quarantine artifacts, working in-memory
  client returned.
- [ ] Quarantine path: all four sidecar suffixes moved; recreate succeeds; existing
  garbage-bytes pin green.
- [ ] `swift test --filter MakeLiveTests` + full `make test` + `make lint` green.

Evidence: test output transcript.

## Steps

### RED
- [ ] Classifier + preserve/quarantine tests (fail against blanket-`try?` code).

### GREEN
- [ ] Classification, injectable open, journal suffix, log lines, Package.swift dep.

### REFACTOR
- [ ] The CR-2 doc comment rewritten to tell the discrimination story (quarantine =
  proven corruption only); lint clean.

## Notes

Do not change `liveValue`'s shape — it still calls `makeLiveResilient(path:)` with the
default `open`. The in-memory last-resort `try!` stays (fundamentally broken SQLite =
honest crash). Log dependency: resolve `@Dependency(\.log)` inside the function (pattern:
HKDeltaReads after 18.2). Tests assert BOTH behaviour (files) AND the emitted `.http`
record (round-2 #2) — a silent regression of the decision record would recreate the
audit's no-trace failure mode.
