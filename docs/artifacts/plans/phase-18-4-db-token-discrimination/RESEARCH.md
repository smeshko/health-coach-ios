# Research: Resilient-DB and token-restore discrimination

Curated findings only — no raw conversation transcripts.

## Key Files & Directories

- `Sources/Clients/Database/Sources/DatabaseLive.swift` — the target.
  `makeLiveResilient(path:)` (lines 44-53): `if let db = try? makeLive(path:)` swallows the
  error → EVERY failure quarantines. `quarantineDatabaseFile` (58-66) moves suffixes
  `["", "-wal", "-shm"]` — no `-journal`. `liveValue` (73-79) resolves the path and calls
  `makeLiveResilient`; the composition root does not set `database` explicitly.
- `Sources/Clients/Database/Tests/MakeLiveTests.swift` —
  `test_makeLiveResilient_recoversFromCorruptFile_quarantinesIt` (garbage-bytes file) is the
  existing integration pin; must keep passing (garbage → SQLITE_NOTADB → still quarantines).
- `Sources/Features/AppFeature/Sources/AppFeature.swift` — `_restoreSession` (line ~144):
  `let token = try? await tokenClient.read()` then
  `_tokenChecked(hasToken: token?.isEmpty == false)` — a thrown read is
  indistinguishable from no-token → onboarding swap at the `guard !hasToken` arm.
- `Sources/Clients/TokenClient/Sources/TokenClient+Live.swift` — `KeychainTokenStore.read()`
  returns nil ONLY for `errSecItemNotFound`; any other status throws
  `KeychainError.unexpectedStatus(status)` — the thrown-vs-nil discrimination already
  exists at the source; the collapse is in the caller.
- `Sources/Features/AppFeature/Tests/AppFeatureTests/AppFeatureSwitchTests.swift` — the
  restore-path tests (`test_restoreSession_missingToken_swapsToOnboarding` parameterized
  over nil/""), `receive(\._tokenChecked, false)` shape.
- `Sources/Features/AppFeature/Tests/AppFeatureTests/ActionLoggingTests.swift:29` — sends
  `._tokenChecked(hasToken: true)` and asserts the payload-free `.tca` log label.
- `Package.swift` — `Database` target deps: CoachCore, PersistenceModels, Dependencies,
  GRDB only. LogClient must be added for the discrimination log lines (18.2 precedent:
  HealthKitClientLive gained LogClient the same way).

## Architecture Facts

- GRDB 7 (`from: "7.0.0"`); the primitive is `DatabaseQueue` (NOT Pool) → SQLite default
  rollback-journal mode → the sidecar that actually exists is `path + "-journal"`; `-wal`/
  `-shm` exist only if WAL was ever enabled. Epic explicitly calls out this quarantine gap.
- `GRDB.DatabaseError` carries `resultCode`/`extendedResultCode` (`ResultCode`). Corruption
  codes: `.SQLITE_CORRUPT` (11), `.SQLITE_NOTADB` (26). Transient/lockable:
  `.SQLITE_BUSY` (5), `.SQLITE_LOCKED` (6), `.SQLITE_IOERR` (10), `.SQLITE_FULL` (13),
  `.SQLITE_CANTOPEN` (14). Migration bugs surface as arbitrary thrown errors (often not
  `DatabaseError` at all) → must classify as preserve.
- Every table is a re-derivable cache or re-enterable state (the existing CR-2 comment) —
  quarantine on REAL corruption remains correct; the fix is the discrimination, not the
  recovery shape.
- AppFeature default route is `.main`; the §13 session stream routes to onboarding on a
  real 401 — so "stay put on read error" degrades safely even if the token is actually
  gone.
- The `.tca` action log renders case labels only (payload-free, Mirror-based) — renaming
  `_tokenChecked`'s payload shape does not change the logged label.

## Constraints

- `logActions()`/ActionLoggingTests expect the `_tokenChecked` label — keep the action name.
- In-memory fallback must remain the LAST resort and never wipe the on-disk file on the
  preserve path — assert file bytes untouched in the preserve tests.
- `make test` covers Database + AppFeature targets on the host (no HealthKit-style sim-only
  arm here; GRDB runs on macOS). Standard suite + lint gates apply.
- No new UI: `readFailed` produces log lines + staying put, no alert (single-owner app;
  the log viewer is the diagnostic surface).

## Useful Commands

```bash
make test    # host suite (Database + AppFeature targets included)
make lint
swift test --filter MakeLiveTests
swift test --filter AppFeatureSwitchTests
```

## Uncertainty

- Whether `DatabaseError` is publicly constructible with an arbitrary `resultCode` in
  GRDB 7 for the forced-error tests — fallback documented in PLAN Risks (classify via the
  injected `open` closure throwing a custom error type, or classify on `ResultCode`
  directly).
- Whether quarantining should also handle `.SQLITE_CANTOPEN` as corruption — resolved: no;
  cantopen is path/permission trouble, wiping doesn't help, preserve is safe (next launch
  retries).

## References

- `docs/artifacts/epics/18-run-on-device.md` — Phase 18.4 goal/criteria.
- `docs/artifacts/audits/AUDIT-2026-07-05.md` — corruption-vs-transient discrimination
  finding (CR-2 lineage).
- Commit `15d74e1` — the CR-2 `makeLiveResilient` this phase refines.
