# Adversarial Review — Round 1

**Run:** 2026-07-10 13:29 UTC
**Branch:** fix/phase-18-4-db-token-discrimination
**Base:** staging
**Commits reviewed:** 1c4b133..fa49d61
**Reviewer:** Codex (`/codex-local:adversarial-review --wait --scope branch --base staging`)

## Codex output

<!-- Paste /codex:adversarial-review stdout verbatim below this line. Do not edit. -->

# Codex Adversarial Review

Target: branch diff against staging
Verdict: needs-attention

No-ship: the new recovery paths still permit a crash loop, silent write loss, and an unrecoverable persistent Keychain failure.

Findings:
- [high] Migration failures still crash despite the resilient-open contract (Sources/Clients/Database/Sources/DatabaseLive.swift:70-71)
  A non-SQLite migration failure is classified as `.preserve`, but this path then force-unwraps `makeInMemory()`. That function runs the same migrator, so an unconditional bad/future migration throws again and `try!` terminates the process. The stated fallback for migration errors therefore cannot protect launch from the failure it claims to handle.
  Recommendation: Remove the force-try from both fallback arms and provide an explicit unavailable-persistence/launch-error path when the in-memory migration also fails; add a test with a migrator that throws during both disk and in-memory setup.
- [high] A transient DB-open failure still silently discards user writes (Sources/Clients/Database/Sources/DatabaseLive.swift:61-71)
  On every non-corruption open failure, the app returns a fully writable in-memory database. Repository writes can succeed and normal UI flow continues, but all entries made during that session disappear at process exit. The only warning is an asynchronously persisted cache log, which is not a user-facing durability guarantee and may be purged.
  Recommendation: Do not expose a writable normal database while durable storage is unavailable. Retry/reopen before enabling writes, surface a persistence-unavailable state, or queue writes durably for replay.
- [medium] Persistent Keychain failures leave the user in a dead-end main route (Sources/Features/AppFeature/Sources/AppFeature.swift:189-202)
  `readFailed` clears the launch overlay and starts the normal main flow, but token-dependent requests re-read the Keychain before sending and will fail before emitting a 401. There is no foreground retry or recoverable auth state here, so a persistent Keychain status leaves the user on main with failing requests; the existing reconnect flow also requires a successful Keychain clear before it can route to onboarding.
  Recommendation: Keep the user out of the normal authenticated flow on persistent read failure: present a recoverable session/persistence state with an explicit retry on foreground/unlock and a supported path to reconnect once Keychain access returns.

Next steps:
- Fix the forced in-memory migration crash and prevent accepting non-durable writes before shipping.
- Add device-level tests for persistent Keychain unavailability and disk/migration failure recovery.

## Triage

| # | Finding | Severity | Verdict | Rationale | Commit |
|---|---------|----------|---------|-----------|--------|
| 1 | `try! makeInMemory()` crashes if the migrator also throws in-memory | med | defer | The crash slice needs a migration that throws on an EMPTY database — unshippable here, since the entire test suite (483 tests) builds fresh migrated in-memory DBs, so CI catches that bug class before release; the realistic device-side migration failure is data-dependent (existing on-disk state), exactly what the preserve arm handles, and `makeInMemory` succeeds there. The `try!` last resort is pre-existing retained semantics (also in `liveValue`), documented as the honest outcome for a fundamentally broken SQLite environment. A non-crashing unavailable-persistence client (stub `DatabaseReader`/`DatabaseWriter` conformance) is real machinery out of this branch's scope — follow-up. | |
| 2 | In-memory fallback silently discards session writes | high | reject | Re-litigates the explicit PLAN Decision "In-memory fallback's session write-loss is explicit, not silent" (validation round-3 #1, slim arm): these are the PRE-EXISTING last-resort semantics (CR-2 — every table is a re-derivable cache or re-enterable state), now strictly better because the on-disk data survives; the log record states "NEW WRITES WILL NOT PERSIST" outright, and a read-only persistence state / durable replay queue was already weighed and DEFERRED as a recorded known limitation for a rare transient on a single-owner app. | |
| 3 | Persistent Keychain failure leaves the user on a dead-end `.main` | med | reject | Re-litigates the explicit PLAN Decision "`readFailed` stays on `.main`", which enumerates this exact spectrum: persistent failure → no request can be built → no 401 → user stays on `.main` with Today's sync-error surface + the always-on `.http` record naming the cause; relaunch is the recovery — accepted for a single-owner app. Swapping to onboarding on error would deliberately re-create the audit's stranding bug; and under a device-level persistent Keychain failure onboarding could not save a token either, so no route change helps. The dedicated recoverable auth state with foreground re-read is already recorded as deferred in the reducer comment. | |
