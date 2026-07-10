# Research: Onboarding-probe and Connect hardening

Curated findings only — no raw conversation transcripts.

## Key Files & Directories

- `Sources/Features/OnboardingFeature/Sources/ConnectComponent.swift` — the target reducer.
  `connectTapped` effect: write candidate → `apiClient.probe()` → `probeResponse`. NO
  CancelID anywhere. `probeResponse(.failure)` treats every error identically: `.invalid` +
  `tokenClient.clear()`. `binding`/`tokenPasted` reset `validation = .idle` but do NOT
  cancel the in-flight probe → the stale-failure race the epic names.
- `Sources/Features/OnboardingFeature/Sources/ConnectView.swift` — error row keys off
  `validation == .invalid` (tinted field + inline row; fixed copy, "no raw error string"
  rule in the doc comment). New `.unreachable` reuses this structure.
- `Sources/Features/OnboardingFeature/Sources/HealthKitPriming.swift` — probe effect at
  `authorizationResponse(.success)`: `deltaSamples(.since(.distantPast))` (18.2's mechanical
  adaptation → sync-default bounds 10 000/15s). `degradedProbeResponse(.failure)` already
  degrades to ALL rows (the timeout path exists; needs a dedicated pin + tighter bounds).
  `.checking` phase has no CTA — settling OUT of it is the requirement.
- `Sources/Features/OnboardingFeature/Tests/OnboardingFeatureTests/` —
  `ConnectComponentTests.swift`, `HealthKitPrimingTests.swift` (TestStore, exhaustive).
- `Sources/Clients/HealthKitClient/Interface/HealthKitClient.swift` — `HealthReadBounds`
  (18.2): memberwise init + `.since(_:)` factory; `limitPerType` clamped ≥ 1;
  `activitySince` floors the ACTIVITY WINDOW at `limitPerType - 1` days (inclusive
  endpoints, review #3.1).
- `Sources/Clients/APIClient/Interface/APIError.swift` — `.unauthorized` (401) vs
  `.transport(String)` (network/unconfigured) — the discrimination axis; Equatable.

## Architecture Facts

- Stale-probe race (real today): edit during `.validating` → UI resets to `.idle`, old probe
  keeps running → late `.failure` sets `.invalid` + `clear()`s whatever token is now stored
  (possibly a newer, valid one written by a second connect).
- AppFeature launch restore checks token PRESENCE only (until 18.4) — an unvalidated
  candidate left in the Keychain would flip the next launch to `.main`. Hence: candidate is
  cleared on every failure; only the presentation discriminates.
- `limitPerType` is dual-purpose (rows per sample type AND activity window days) — a
  presence probe with `limitPerType: 1` would mark activity "missing" unless a summary
  exists TODAY, breaking the "old-but-granted reads present" probe semantics (DECISIONS #2
  in HealthKitPriming).
- The 18.1 `.unconfigured` client throws `APIError.transport("API base URL not
  configured…")` — lands in the non-401 arm → `.unreachable`, closing the 18.1 defers
  (config failure presented as reachability + candidate not presented as "rejected").
- TCA cancellation: `.cancellable(id:cancelInFlight:)` + `.cancel(id:)` merged from the
  edit actions; cancelled effects deliver nothing (TestStore asserts by exhaustivity).

## Constraints

- OnboardingFeature has snapshot tests (`OnboardingFeatureSnapshotTests` in Makefile
  SNAPSHOT_TARGETS) — the new `.unreachable` render needs ONE new PNG recorded on the pinned
  sim (`make record-snapshots`, review diff; memory: snapshot-rerecord-workflow).
- Existing `.invalid` snapshots must NOT change (copy/tint untouched for that case).
- `test_` prefix + `import Foundation` in new Swift Testing files; no a11y additions
  (memory: no-a11y-personal-app).
- Carried defers this phase must close (from 18.1 REVIEW/VALIDATION): "unconfigured DEBUG
  device build cannot complete onboarding shows token-rejected" and "typed
  configuration-failure presentation; unconfigured must not clear a valid token" — both are
  satisfied by the discrimination + cancellation design (see PLAN Decisions for the
  candidate-clearing rationale).

## Useful Commands

```bash
make test    # host suite
make lint
make test-snapshots      # pinned-sim snapshots (all SNAPSHOT_TARGETS)
make record-snapshots    # record mode (expected non-zero exit; review PNG diff)
```

## Uncertainty

- Whether cancelling on every `binding` keystroke is too aggressive vs only on
  `connectTapped` re-entry — resolved: an edited field invalidates the in-flight candidate
  by definition; cancel on both (documented in PLAN Risks).
- Exact new copy for `.unreachable` — implementer picks short fixed copy consistent with
  the design system tone (e.g. "Can't reach the server — check your connection"), no raw
  error strings.

## References

- `docs/artifacts/epics/18-run-on-device.md` — Phase 18.3 goal/criteria.
- `docs/artifacts/plans/archive/2026-07-10-phase-18-1-production-base-url/REVIEW.md` —
  the carried defers (round-1 #2 / round-2 #1b; validation round-3 #1 presenter arm).
- 18.2 `HealthReadBounds` review trail (activity-window semantics, review #2.2/#3.1).
