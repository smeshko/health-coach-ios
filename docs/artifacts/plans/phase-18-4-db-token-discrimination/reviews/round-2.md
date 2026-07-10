# Adversarial Review — Round 2

**Run:** 2026-07-10 13:35 UTC
**Branch:** fix/phase-18-4-db-token-discrimination
**Base:** staging
**Commits reviewed:** 1c4b133..fa49d61
**Prior rounds in scope:** reviews/round-1.md
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging` + round-1 triage in focus)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No-ship. I disagree with all three round-1 dispositions: the documented tradeoffs still leave user-visible data loss, an unrecoverable auth outage, and a launch crash path. No additional material issue was substantiated.

Findings:
- [high] Preserve-mode accepts writes that are silently lost to the owner (Sources/Clients/Database/Sources/DatabaseLive.swift:61-71)
  On every non-corruption open failure, this returns a normal writable in-memory client. The only durability warning is a log line; there is no UI state, write rejection, or durable replay. Logs reside in Caches and are not an acknowledgement to the user, so a check-in or other session work can appear saved and vanish on exit. The PLAN decision records this loss but does not make it safe; SQLITE_FULL, I/O, and lock failures are explicitly routed here.
  Recommendation: Do not expose normal writable persistence in this state. Surface persistence-unavailable and block writes, or queue writes durably and replay only after the on-disk database reopens.
- [medium] Persistent Keychain read failures still strand the app in an unusable main route (Sources/Features/AppFeature/Sources/AppFeature.swift:189-202)
  I disagree with the rejection rationale. This arm removes the launch overlay and starts Today, but every protected request re-reads the token before constructing a request. A persistent read error therefore produces neither a request nor a 401 route change, and the reducer has no foreground/unlock retry or user recovery action. A cached screen or an error log is not a recoverable authenticated state; relaunch is not a remedy for the documented persistent case.
  Recommendation: Model token-store unavailability explicitly, retry on foreground/unlock, and provide a visible recovery path while preventing authenticated work until a token read succeeds.
- [medium] The resilient-open fallback can still terminate the process (Sources/Clients/Database/Sources/DatabaseLive.swift:61-95)
  Both recovery arms force-unwrap `makeInMemory()`, which reruns the migrator. The defer rationale only establishes that CI exercises a fresh in-memory schema; it does not protect against a device-only SQLite/resource/configuration failure or a future migration failure that also affects a fresh database. In either case the code crashes precisely while handling the open failure it claims to make launch-resilient.
  Recommendation: Replace both force-tries with an explicit unavailable-persistence client/state and test an in-memory migration/setup failure.

Next steps:
- Resolve the durability and auth-recovery states before shipping; do not treat internal logging or relaunch as user recovery.

## Triage

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | Preserve-mode accepts writes that are silently lost (re-raise of round-1 #2) | high | reject | Rejection stands: this is the explicit PLAN Decision (validation round-3 #1, slim arm) — Codex acknowledges the Decision records the loss and disagrees with the tradeoff, which is a decision-level challenge, not a new defect. The semantics are the PRE-EXISTING last-resort behavior (CR-2: every table is a re-derivable cache or re-enterable state), strictly improved by this branch because the on-disk data now survives; the persistence-unavailable UI / durable replay queue was weighed and DEFERRED there as a recorded known limitation for a rare transient on a single-owner app. | |
| 2 | Persistent Keychain failure strands `.main` (re-raise of round-1 #3) | med | reject | Rejection stands: the PLAN Decision "`readFailed` stays on `.main`" documents this exact persistent-case spectrum and accepts it for a single-owner app, with the always-on `.http` record as the reliable trace. No route change helps under a device-level persistent Keychain failure (onboarding's Connect could not save a token either, and reconnect requires a Keychain clear); swapping on error is the audit's stranding bug this phase removes. Foreground-retry / token-store-unavailable state remains the recorded deferred follow-up. | |
| 3 | Force-try `makeInMemory()` can still terminate the process (re-raise of round-1 #1) | med | defer | Defer stands (already captured as the round-1 #1 follow-up): the residual slice is a device-only fresh-DB/SQLite-environment failure, whose crash was ALREADY the documented pre-branch last-resort behavior (`liveValue` has the same force-try on staging) — this branch narrows, never widens, the crash surface. An unavailable-persistence stub client conforming to GRDB's reader/writer protocols is real machinery beyond this phase's scope. | |
