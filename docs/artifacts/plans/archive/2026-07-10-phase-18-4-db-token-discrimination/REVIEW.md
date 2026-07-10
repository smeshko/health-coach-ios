# Review Summary — phase-18-4-db-token-discrimination

**Rounds:** 2
**Fix commits:** none (0 fixes)

## Rounds

| Round | Findings | Fixed | Deferred | Rejected |
|-------|----------|-------|----------|----------|
| 1     | 3        | 0     | 1        | 2        |
| 2     | 3 (all re-raises of round 1) | 0 | 1 (same defer) | 2 (same rejects) |

## Fixes

None. Both rounds produced only decision-level challenges to tradeoffs explicitly adjudicated in PLAN.md Decisions during plan validation; no implementation defect was found.

## Deferred

- (round-1 #1 / round-2 #3) `try! makeInMemory()` in the resilient-open fallback arms can still terminate the process if the in-memory open/migration itself fails — replace with an explicit unavailable-persistence client/state and test an in-memory setup failure. Rationale: the crash slice needs either a migration that throws on an EMPTY database (unshippable — the whole 483-test suite builds fresh migrated in-memory DBs, so CI catches that bug class) or a device-only broken-SQLite environment, whose crash was already the documented pre-branch last-resort behavior (`liveValue` carries the same force-try on staging); this branch narrows, never widens, the crash surface. A stub `DatabaseReader`/`DatabaseWriter` conformance is real machinery beyond this phase's scope. *(Linear not wired — recorded here only.)*

## Rejected

- (round-1 #2 / round-2 #1) Preserve-mode returns a writable in-memory DB whose session writes are silently lost — rejected per the explicit PLAN Decision "In-memory fallback's session write-loss is explicit, not silent" (validation round-3 #1, slim arm): these are the PRE-EXISTING last-resort semantics (CR-2 — every table is a re-derivable cache or re-enterable state, never the account), strictly improved by this branch because the on-disk data now survives; the log record states "NEW WRITES WILL NOT PERSIST" outright, and a persistence-unavailable UI / durable replay queue was weighed there and DEFERRED as a recorded known limitation for a rare transient on a single-owner app.
- (round-1 #3 / round-2 #2) Persistent Keychain read failure leaves the user on a dead-end `.main` with no foreground retry — rejected per the explicit PLAN Decision "`readFailed` stays on `.main`", which enumerates this exact spectrum: transient failure → the next request's per-call token read succeeds; persistent failure → no request can be built → no 401 → the owner stays on `.main` with Today's existing sync-error surface + the always-on `.http` record naming the cause, relaunch as recovery — accepted for a single-owner app. Swapping to onboarding on a read ERROR would deliberately re-create the audit's stranding bug, and under a device-level persistent Keychain failure no route change helps (Connect could not save a token either; reconnect needs a Keychain clear). The dedicated recoverable auth state with foreground re-read is recorded as deferred in the reducer comment.
