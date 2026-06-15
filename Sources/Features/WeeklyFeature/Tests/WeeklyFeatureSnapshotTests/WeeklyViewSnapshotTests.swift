// Weekly shell snapshots land in Phase 9.1 TASK-005 (the rendered shell — normal / deload / collapsed
// states, light + dark). The target is declared from TASK-001 so the SnapshotTesting harness + the
// Makefile `SNAPSHOT_TARGETS` wiring exist from the feature's first commit; the test bodies + the
// committed `__Snapshots__` references arrive in TASK-005. Host-guarded so the target compiles to an
// empty module under `swift build`/`swift test` (the snapshots run on the pinned iOS simulator only).
#if canImport(UIKit)
#endif
