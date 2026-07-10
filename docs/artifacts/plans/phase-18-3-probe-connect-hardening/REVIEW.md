# Review Summary — phase-18-3-probe-connect-hardening

**Rounds:** 2
**Fix commits:** none

## Rounds

| Round | Findings | Fixed | Deferred | Rejected |
|-------|----------|-------|----------|----------|
| 1     | 1        | 0     | 0        | 1        |
| 2     | 2        | 0     | 0        | 2 (1 re-push of round-1 #1) |

## Fixes

None — no finding survived triage as a real bug in this branch.

## Deferred

None. (Linear not wired for this plan — `Linear: none`.)

## Rejected

- (round-1 #1, re-pushed as round-2 #1) Non-401 server-replied errors (`.decoding`, `.envelope`, `.unexpectedStatus`) render as "Can't reach the server" — PLAN.md Scope explicitly decides "ANY other error → `.unreachable`" and AC-2 pins `.decoding` → `.unreachable` as a tested arm. Only a 401 is a token VERDICT; every other failure must not read as token rejection, which is the phase's point. The copy ("check your connection and server address") is the actionable remedy for the realistic non-401 server-responded failures here (wrong base URL → 404/HTML → `.unexpectedStatus`/`.decoding`); a transport-vs-response split would mislabel those as server faults. Candidate clearing, retry (re-tap), and remedy surface are identical in both arms, the D19 "no raw error strings" rule forbids surfacing the thrown message, and the always-on `.http` log carries the precise cause (18.1 diagnostic). Single-owner self-hosted deployment: the copy's reader operates the server.
- (round-2 #2) `presenceProbe` `limitPerType: 365` shrinks the activity presence window to 1 year, so >1-year-dormant activity rings would read "Not shared" — contradicts the explicit PLAN.md Decision that names exactly this trade-off ("365 keeps 'old-but-granted reads present' true for a year of inactivity while staying firmly bounded"). The prior ~10,000-day window was 18.2's incidental sync default, not a designed probe semantic; HK read-presence is inherently heuristic (Apple masks read grants); the residual case lands on a non-blocking informational screen (Continue + Open Health settings), not a hard block. Decoupling the activity window from `limitPerType` would reopen the 18.2 dual-purpose bounds design — explicitly out of scope ("any change to the 18.2 read internals — consumed as-is").
