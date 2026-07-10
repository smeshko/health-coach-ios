# Adversarial Validation — Round 3

**Run:** 2026-07-10
**Plan:** phase-18-3-probe-connect-hardening
**Status at start:** draft
**Reviewer:** subagent (general-purpose; Codex usage-limited)
**Prior rounds in scope:** validation/round-1.md, validation/round-2.md

## Reviewer output

<!-- Subagent output verbatim below this line. Do not edit. -->

Verdict: needs-attention

Both of the prompt's mechanics questions check out against the vendored TCA source, so the round-2 respec is *structurally* right: `.cancellable(id:cancelInFlight:true)` on the edit-arm clear does cancel the probe registered under the same ID (`withTaskCancellation` cancels every cancellable under the ID before registering itself — `.build/checkouts/swift-composable-architecture/Sources/ComposableArchitecture/Effects/Cancellation.swift:173-180`), a cancelled probe's `send(.probeResponse)` is provably dropped (`Send.callAsFunction` guards `!Task.isCancelled` — `Effect.swift:191-193`), and `connectTapped`'s own `.cancellable(id: CancelID.probe, cancelInFlight: true)` IS already specced (TASK-001:15-16). What the edits missed is that TCA cancellation is *cooperative* — and the specified effect bodies never cooperate.

Findings:

1. [med] The specified clear body ignores cancellation, so "the next `connectTapped` cancels a pending clear BEFORE writing" is inert as written. TASK-001:20-24 and PLAN.md:65-68 claim the re-tap's `cancelInFlight` kills a still-pending clear, but the mechanism is `task.cancel()` (Cancellation.swift:177-178) and the body is `try? await tokenClient.clear()` — no cancellation point aborts it: a cancelled-but-unstarted `Task` still runs its body, an actor hop (`TokenClient+TestValue.swift`'s `TokenBox.set`) or live Keychain call completes regardless, and `try?` would swallow a `CancellationError` anyway. So the round-2 #1 interleave (write → zombie clear → unauthenticated probe → false `.invalid`) is narrowed, not closed, and the specced ordering test (TASK-001:39-40) only goes green if the clear stub parks at a cancellation-aware suspension *before* recording — proving stub plumbing, not the live body (a plain-continuation park hangs the test). Recommendation: Verdict: apply — spec `try Task.checkCancellation()` as the first statement of the clear body, require cancellation-aware parked stubs (probe stub too) in the test bullets, and soften the Decisions wording to "guarded best-effort; residual window is one actor-hop vs a human re-tap" — TASK-001 (Files, tests), PLAN.md (Decisions bullet 2).

2. [low] Symmetric zombie on the probe side: a cancelled probe can still complete `tokenClient.write(candidate)` after the edit's clear ran. The write is the probe effect's first await (ConnectComponent.swift:82); an edit-arm cancel landing between task spawn and the write doesn't stop it (cooperative), so the ordering clear-then-write leaves an unvalidated candidate stored with `validation == .idle` — the exact round-1 #1 invariant ("an unverified candidate must not persist", PLAN.md:38-40) reopened by scheduling. Recommendation: Verdict: apply — one line, `try Task.checkCancellation()` before the write in `connectTapped`'s effect body (TCA's `.run` swallows `CancellationError` silently) — TASK-001 (Files).

3. [low] The failure-arm clear keeps the exact detached shape round-2 #1 outlawed. TASK-001:27 says `.invalid` "(+ clear, unchanged)", leaving ConnectComponent.swift:101's `.run { try? await tokenClient.clear() }` unregistered under any ID — so neither an edit nor a re-tap can cancel it, and the pending-failure-clear → re-tap → write → stray-clear interleave runs through the *primary* retry flow (failure → edit → re-submit). Same theoretical-only window as round-2 #1, which the plan applied at [med]; by its own accepted threat model this arm needs the same treatment or an explicit exemption. Recommendation: Verdict: apply — register both failure-arm clears (`.invalid` and the new `.unreachable`) under `CancelID.probe` with `cancelInFlight: true` (or add a one-line Decisions exemption saying why detached is acceptable there) — TASK-001 (Files), PLAN.md (Decisions).

4. [low] TASK-001's NOTE now contradicts its own test list about `cancelInFlight` testability. Lines 45-49 still carry the round-1 #2 reframe verbatim ("untestable defense-in-depth … do not write a fake test for it") while lines 39-40 spec an ordering test that exercises precisely `connectTapped`'s `cancelInFlight` against the pending clear — the round-2 respec gave the flag a real, testable target the reframe predates. PLAN.md:102-103's parenthetical stays accurate only for the *concurrent-second-probe* claim. Recommendation: Verdict: apply — qualify the NOTE to "untestable w.r.t. a concurrent second probe; the pending-clear cancellation IS the testable half (the ordering test)" — TASK-001 (Notes).

Grounding notes (checked, no defect): `APIError` is `Equatable` with a bare `.unauthorized` and `.transport(String)` (APIError.swift:6-14), so TASK-001's discrimination compiles; ConnectView's equality checks keep the new case compile-safe; `ErrorDisplay` is `CaseIterable` with no `.serverUnreachable` collision and TASK-002's "no gallery ripple" claim stands; TASK-003 is fully grounded (presenceProbe factory + timeout pin need no new path); round-2 #2's applied bullet correctly anticipates the in-flight-effect RED.

## Triage

| # | Finding | Severity | Verdict | Rationale | Applied to |
|---|---------|----------|---------|-----------|------------|
| 1 | Clear body never cooperates with cancellation — pending-clear kill is inert; test stubs must park cancellation-aware | med | apply | Correct — `Task.checkCancellation()` leads the clear body; stub requirements + softened wording applied | TASK-001:Files/Tests, PLAN.md:Decisions |
| 2 | Cancelled probe can still complete the token write | low | apply | `checkCancellation` before the write specced | TASK-001:Files |
| 3 | Failure-arm clears keep the outlawed detached shape | low | apply | Both failure clears registered under `CancelID.probe` | TASK-001:Files |
| 4 | NOTE contradicts the ordering test on cancelInFlight testability | low | apply | NOTE qualified: concurrent-second-probe untestable; pending-clear IS the testable half | TASK-001:Notes |

**Round-3 note (protocol):** round-3 applies would normally stop for the user; the run is
user-ordered autonomous ("don't stop for questions"). All four findings refine one
mechanism (cooperative cancellation of the clear/probe bodies) already specced in rounds
1–2 — applied and concluded, no fourth round. TCA mechanics were verified against the
vendored source by the reviewer.
