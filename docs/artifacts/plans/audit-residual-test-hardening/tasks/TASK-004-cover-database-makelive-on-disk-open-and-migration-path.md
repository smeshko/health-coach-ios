# TASK-004: Cover Database.makeLive on-disk open and migration path

Depends on: None
Suggested commit: `test(database): cover makeLive on-disk open + cross-open migration`

## Goal

Test `DatabaseClient.makeLive(path:)` — the production entry point (`liveValue`) that
every existing test bypasses in favor of `makeInMemory()` — for on-disk open, migration
from scratch, and idempotent re-open over the same file (the app-relaunch path).

## Files

- `Sources/Clients/Database/Tests/` — add a test file (mirror
  `StrengthWeekMigrationTests.swift` / `DomainBodyCacheMigrationTests.swift`): build a
  unique temp path under `NSTemporaryDirectory()`, `makeLive(path:)` it (migrates from
  scratch on disk), write a row through the returned client, then `makeLive(path:)` the
  SAME path again (simulating a second app launch) and assert the row persists, the
  schema is fully migrated, and the second open does not error. Delete the temp file in
  teardown.

## Acceptance

- [ ] First `makeLive(path:)` on a fresh temp file creates + migrates the on-disk DB; a
      written row reads back.
- [ ] A second `makeLive(path:)` over the same file opens cleanly (migrations idempotent)
      and the row from the first open survives.
- [ ] The temp file is removed after the test (no leakage between runs).
- [ ] Host + sim suites green.

## Steps

### RED
- [ ] Write the on-disk open/re-open test against `makeLive(path:)` (fails if the on-disk
      path or cross-open migration misbehaves — `makeInMemory` can't exercise either).

### GREEN
- [ ] n/a — coverage of existing production code; fix only if the test exposes a defect.

### REFACTOR
- [ ] Run the full Database suite; confirm no temp-file leakage; host + sim suites.

## Notes

`makeLive(path:)` (`DatabaseLive.swift:10-14`) runs `migrator.migrate(queue)` on a
`DatabaseQueue(path:)`; in-memory hides file-mode failures and cross-open migration
ordering. Use a per-test unique filename to keep parallel test runs isolated.
