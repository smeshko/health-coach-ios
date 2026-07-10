# TASK-003: Priming presence-probe bounds + timeout-degrade pin

Depends on: TASK-001
Suggested commit: `fix(onboarding): dedicated presence-probe bounds; pin timeout→degraded`

## Goal

The onboarding presence probe runs under bounds sized for "is anything there" (not a full
delta read), and a probe timeout provably lands on the actionable degraded screen.

## Files

- `Sources/Clients/HealthKitClient/Interface/HealthKitClient.swift` —
  `public static func presenceProbe(since: Date = .distantPast) -> HealthReadBounds`
  with `limitPerType: 365`, `timeout: .seconds(10)`. Doc comment MUST explain the 365:
  `limitPerType` doubles as the activity-summary window in days (18.2 review #2.2/#3.1),
  so a presence probe can't use 1 — activity would only read "present" with a summary
  today; 365 keeps "old-but-granted reads present" true for a year of inactivity. 10s <
  the 15s sync default because the user is actively waiting on the onboarding screen.
- `Sources/Features/OnboardingFeature/Sources/HealthKitPriming.swift` — the probe effect
  uses `deltaSamples(.presenceProbe())`; update the DECISIONS #2 comment (probe is now
  bounded but presence semantics preserved).
- `Sources/Clients/HealthKitClient/Tests/HealthReadBoundsTests.swift` — factory test
  (since/limit/timeout values).
- `Sources/Features/OnboardingFeature/Tests/OnboardingFeatureTests/HealthKitPrimingTests.swift` —
  - stub client captures the bounds → assert `.presenceProbe()` values arrive.
  - new pin: probe throws `HealthKitReadError.timedOut` → `.degraded(all rows)` (the
    Continue CTA state), never stuck `.checking` — the epic's acceptance in TestStore form.

## Acceptance

- [ ] Bounds-capture test: the probe requests since == .distantPast, limitPerType == 365,
  timeout == .seconds(10).
- [ ] `.timedOut` probe → `.degraded(DegradedSummary(missing: all))`; phase left
  `.checking` in every asserted path.
- [ ] `make test` + `make lint` green.

Evidence: test output transcript.

## Steps

### RED
- [ ] Bounds-capture + timeout-degrade tests (fail: current code passes `.since(.distantPast)`).

### GREEN
- [ ] `presenceProbe` factory + call-site swap.

### REFACTOR
- [ ] Comments accurate (probe bounded, presence semantics, why 365); lint clean.

## Notes

Do not change the degrade-on-failure arm itself — it already handles the timeout correctly
(18.2 made `deltaSamples` throw `.timedOut`); this task pins it and tightens the bounds.
No UI change: `.checking` still has no CTA by design — settling out of it within 10s is
the guarantee.
