# TASK-001: ConnectComponent: probe CancelID + 401-vs-transport discrimination

Depends on: None
Suggested commit: `fix(onboarding): cancellable Connect probe; unreachable ≠ invalid token`

## Goal

A stale or transient probe failure can neither clear a newer token nor masquerade as
"token invalid": in-flight probes are cancelled on edit/re-submit, and only a 401 renders
the invalid state.

## Files

- `Sources/Features/OnboardingFeature/Sources/ConnectComponent.swift` —
  - `private enum CancelID { case probe }`; the `connectTapped` effect gains
    `.cancellable(id: CancelID.probe, cancelInFlight: true)`.
  - `binding` and `tokenPasted` arms: `state.validation = .idle` (unchanged) and return
    ONE effect — `.run { try Task.checkCancellation(); try? await tokenClient.clear() }
    .cancellable(id: CancelID.probe, cancelInFlight: true)` (validation round-1 #1, shape
    round-2 #1, cooperation round-3 #1). TCA cancellation is COOPERATIVE: without the
    leading `checkCancellation` a cancelled-but-unstarted clear still runs its body (an
    actor hop completes regardless; `try?` would swallow the CancellationError). The
    `cancelInFlight` kills the in-flight probe (no separate `.cancel` merge — undefined
    ordering under one ID), and registering the CLEAR under `CancelID.probe` lets the next
    `connectTapped` cancel a pending clear before writing. Clearing when nothing was
    written is a harmless no-op.
  - `connectTapped` effect body: `try Task.checkCancellation()` BEFORE the
    `tokenClient.write(candidate)` (round-3 #2) — a cancelled probe task would otherwise
    still complete the write after an edit's clear ran, re-opening the unvalidated-
    candidate-persists hole by scheduling (`.run` swallows CancellationError silently).
  - Failure arms (`.invalid` AND the new `.unreachable`): the clear effect is registered
    under `CancelID.probe` with `cancelInFlight: true` too (round-3 #3) — the current
    detached `.run { clear }` has the same stray-clear interleave through the primary
    failure → edit → re-submit flow.
  - `Validation` gains `.unreachable`; `probeResponse(.failure(error))` discriminates:
    `error as? APIError == .unauthorized` → `.invalid` (+ clear, unchanged); everything
    else (transport, timeout, the 18.1 unconfigured client's `APIError.transport`) →
    `.unreachable` (+ clear — see PLAN Decisions: an unvalidated candidate must not
    persist, presentation is what changes).
  - Doc comments: update the header's failure story (three outcomes now) and note the
    race closure.
- `Sources/Features/OnboardingFeature/Tests/OnboardingFeatureTests/ConnectComponentTests.swift` —
  - existing failure test split: unauthorized → `.invalid`; transport → `.unreachable`
    (both assert `tokenClient.clear` called).
  - new: edit-mid-probe cancels — `connectTapped` with a parked probe stub, then
    `binding`/`tokenPasted`; TestStore exhaustivity proves no `probeResponse` arrives AND
    `tokenClient.clear` was called (round-1 #1).
  - new: edit→re-tap ordering — after an edit's pending clear, a `connectTapped` cancels
    it before writing (recorder shows write NOT followed by a stray clear; round-2 #1).
    Parked stubs (probe AND clear) must park at CANCELLATION-AWARE suspensions
    (e.g. `withTaskCancellationHandler` around a continuation resumed on cancel) — a
    plain-continuation park hangs the test and proves nothing (round-3 #1).
  - existing `test_editingToken_afterError_resetsValidationToIdle` gains
    `await store.finish()` and asserts the clear via the recorder — the `.binding` arm now
    returns an effect, so the test otherwise fails on an in-flight effect at deinit
    (round-2 #2).
  - NOTE (round-1 #2, qualified round-3 #4): `cancelInFlight` is untestable w.r.t. a
    genuinely CONCURRENT SECOND PROBE (unreachable through `canSubmit` + the cancelling
    edit arms — do not write a fake test for that). The PENDING-CLEAR cancellation is the
    testable half — that is exactly the edit→re-tap ordering test above.

## Acceptance

- [ ] TestStore: no `probeResponse` delivered after a mid-probe edit, and the candidate is
  cleared by the edit (cancel-skips-clear hole closed).
- [ ] `.unauthorized` → `.invalid`; `APIError.transport(...)` → `.unreachable`; candidate
  cleared in both arms.
- [ ] `swift test --filter ConnectComponentTests` + full `make test` + `make lint` green.

Evidence: test output transcript.

## Steps

### RED
- [ ] Write the cancellation + discrimination tests (fail against current single-arm code).

### GREEN
- [ ] CancelID, cancel-on-edit, `.unreachable` arm.

### REFACTOR
- [ ] Header doc comment tells the three-outcome story; lint clean.

## Notes

`canSubmit` blocks re-submit while `.validating` — the re-submit-cancels test must first
edit the field (which flips to `.idle` and cancels) or assert through `tokenPasted`. Check
ConnectView's uses of `validation == .invalid` still compile (they're equality checks, not
exhaustive switches, so adding the case is compile-safe); TASK-002 owns the actual
presentation + snapshot.
