# Adversarial Validation — Round 3

**Run:** 2026-07-10
**Plan:** phase-18-4-db-token-discrimination
**Status at start:** draft
**Reviewer:** Codex (codex-local:adversarial-review)
**Prior rounds in scope:** validation/round-1.md, validation/round-2.md

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the revised plan avoids deleting a healthy DB, but it still permits silent loss of newly entered data and overstates the persistent-Keychain failure experience.

Findings:
- [high] Preserve mode silently accepts writes that vanish at process exit (docs/artifacts/plans/phase-18-4-db-token-discrimination/tasks/TASK-001-databaselive-corruption-vs-transient-discrimination-journal-sidecar-logged-recovery.md:20-28)
  The proposed preserve branch returns a normal working in-memory DatabaseClient for BUSY/LOCKED/I/O/FULL/CANTOPEN and migration failures. That lets check-ins and strength tests appear saved while the on-disk DB remains unavailable; if the app is terminated before a successful reopen, those writes are lost. The byte-identical assertion protects old data only, not data entered during the fallback session. This expands the existing ephemeral fallback to routine non-corruption failures without a user-visible persistence state or a recovery transfer.
  Recommendation: Do not expose an editable in-memory replacement for a preserved on-disk DB unless queued writes are durably replayed after reopen. Otherwise enter an explicit persistence-unavailable/read-only state and test that writes are blocked or retained across recovery.
- [medium] The corruption diagnostic can falsely report a successful recreation (docs/artifacts/plans/phase-18-4-db-token-discrimination/tasks/TASK-001-databaselive-corruption-vs-transient-discrimination-journal-sidecar-logged-recovery.md:20-28)
  The specified corruption record says the database was “quarantined and recreated”, while the same recovery path explicitly permits the recreate open to fail and falls back to memory. A successful quarantine followed by disk-full, I/O, or directory failure would therefore log a false success and conceal that persistence is unavailable. The planned log tests cover the two decisions, but not this second-open failure.
  Recommendation: Log quarantine, recreate success, and recreate failure as distinct outcomes. Add a stateful injected-open test that throws CORRUPT first and a non-corruption error on recreation, asserting the final log and fallback state.
- [medium] The accepted persistent-Keychain rationale is false for common Today routes (docs/artifacts/plans/phase-18-4-db-token-discrimination/tasks/TASK-002-appfeature-three-state-token-restore-present-absent-read-failed.md:23-31)
  Round-1 triage says persistent read failure reaches Today’s existing sync-error surface, but that is not generally true. Today first stops at `.checkInRequired` when no local check-in exists, and a cached-brief launch renders cached content while its background failure is deliberately quiet. Transport does read the Keychain before sending, so no 401 occurs, but the plan only tests the initial failed read and does not define these persistent outcomes. The owner can remain apparently normal or be shown the check-in gate while all authenticated work continues to fail.
  Recommendation: Replace the blanket sync-error claim with tested outcomes for check-in-gated, cache-hit, and cache-miss launches. Prefer an explicit recoverable authentication/persistence error state with a foreground re-read; if that is intentionally out of scope, document and test the degraded routes rather than claiming a surface that may not occur.

Next steps:
- Revise TASK-001 to make fallback-write durability explicit and test failed recreation.
- Revise TASK-002’s persistent-error contract and rerun adversarial validation.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Preserve-mode in-memory session silently loses new writes | high | apply (slim) + defer (machinery) | The write-loss is the PRE-EXISTING last-resort semantics (CR-2: every table re-derivable/re-enterable) and the change makes things strictly better (on-disk data survives where today it is wiped). Applied: the trade is explicit — Decision bullet + the preserve log record says "NEW WRITES WILL NOT PERSIST". Deferred: read-only persistence state / durable replay queue — real machinery for a rare transient on a single-owner app | PLAN.md:Decisions, TASK-001:Files |
| 2 | "Quarantined and recreated" can be a false success when the recreate open fails | med | apply | Correct and cheap — three distinct outcome records + stateful CORRUPT-then-BUSY injected-open test | TASK-001:Files/Tests |
| 3 | Persistent-keychain outcome overstated (check-in gate / quiet cached launch vary) | med | apply (wording) + defer (recovery state) | Correct — comments/plan now describe the variant degraded routes honestly with the `.http` log as the reliable trace; a dedicated recoverable auth-error state with foreground re-read deferred (rare device-level failure, single-owner) | TASK-002:Files, PLAN.md:Decisions |

**Round-3 note (protocol):** round-3 applies would normally stop for the user; the run is
user-ordered autonomous ("don't stop for questions"). #2 applied in full; #1/#3 applied in
their documentation/logging arms with the machinery halves recorded as explicit defers —
concluded, no fourth round.
