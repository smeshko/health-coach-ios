# Research: Bounded, cancellable HealthKit reads

Curated findings only — no raw conversation transcripts.

## Key Files & Directories

- `Sources/Clients/HealthKitClient/Interface/HealthKitClient.swift` — `deltaSamples:
  @Sendable (_ since: Date) async throws -> HealthSampleSet` (single argument — the seam for a
  low-ripple struct swap); `testValue` filters `CannedHealthSamples` by `since`.
- `Sources/Clients/HealthKitClient/Live/HKDeltaReads.swift` — the audit target:
  `runRecordQuery`/`readWorkouts` use `HKObjectQueryNoLimit` + `withCheckedContinuation`
  with NO cancellation observation; `readActivity` is date-range-bounded but equally
  cancellation-deaf. Queries are executed on `HealthStoreBox.store` and never `stop()`ed.
- `Sources/Clients/HealthKitClient/Live/HKSampleMapping.swift` — `recordQuerySpecs`: 23
  specs including HIGH-FREQUENCY types (`.heartRate`, `.stepCount`, `.activeEnergyBurned`,
  `.basalEnergyBurned`, `.physicalEffort`, running metrics) → a 13-month window is
  potentially millions of rows; the row limit is not optional.
- `Sources/Clients/HealthKitClient/Live/HealthKitClientLive.swift` — `HealthStoreBox`
  (`@unchecked Sendable` holder); non-HK platforms get an `.empty` stub client (the `#else`
  arm must keep compiling after the signature change).
- `Sources/Repositories/SyncRepository/Live/SyncRepository+Live.swift` — step 3 wraps the
  read in `withSyncTimeout(healthReadTimeout /* 20s */)` which ABANDONS the operation
  (ResumeOnceFlag race; comment explicitly says HK queries "ignore task cancellation") —
  the orphaned read keeps running. `anchorDate(anchor)` falls back to `backfillFloor`
  (2026-05-23, fixed epoch — a monotonically growing first-sync window). Timeout throws
  `SyncError.transient` BEFORE the watermark write.
- `Sources/Features/OnboardingFeature/Sources/HealthKitPriming.swift:106` — the other call
  site: `deltaSamples(.distantPast)` presence probe (full rework is Phase 18.3; here only the
  mechanical signature adaptation).
- Tests: `SyncTimeoutTests` (TestClock-driven timeout → `.transient`, watermark untouched),
  `SyncOrchestrationTests`, `SyncConcurrencyTests`, `HealthSampleSetFilterTests`,
  `HealthKitPrimingTests` — the suites that feel the signature change.

## Architecture Facts

- Per-category failures degrade to empty slices, never errors (PRD §7.1) — the new timeout
  error is a WHOLE-READ failure and does not change that contract.
- `HKSampleQuery` result handlers run once; `stop(query)` does not guarantee the callback
  fires afterward → the cancellation handler must resume the continuation itself with a
  once-guard (double-resume traps).
- `readActivity` (`HKActivitySummaryQuery`) has no `limit` parameter — it is bounded by the
  date range and covered by cancellation/stop + timeout only.
- Feature-test stubs write `deltaSamples: { _ in ... }` — positional, so a `Date` →
  `HealthReadBounds` swap does not touch them.
- `withSyncTimeout` + `ResumeOnceFlag` (SyncRepository+Live.swift:158-196) is the in-repo
  precedent for the once-guarded race pattern the live cancellation handler needs.

## Constraints

- `sim-unit-tests-must-pass` (memory): no host-only/live-HK tests — live `stop()` behaviour
  is demonstrated via instrumentation (log line) + owner device validation, not unit tests.
- The in-client timeout must be strictly shorter than `healthReadTimeout` (20s) so the
  stopping path fires before the abandoning backstop.
- `DependencyValues.log` lives in the `LogClient` module; `HealthKitClientLive` does NOT
  currently depend on it (Package.swift: only HealthKitClient/WireModels/Dependencies) — the
  `.app` diagnostic needs the target dependency + `import LogClient` added (validation
  round-1 #2).
- `make test` (host `swift test`) never compiles the `#if canImport(HealthKit)` arm — the
  pinned-simulator CoachKit-Package run is the only automated gate that builds the live
  reader (validation round-1 #3).
- `withSyncTimeout` runs its operation in an unstructured `Task` — caller cancellation is
  NOT forwarded today; the plan makes it forward (validation round-1 #1), otherwise the
  stop-on-cancel path is unreachable from Today's Cancel.
- Epic Out of scope: watermark correctness is 19.1 — do NOT change how the anchor advances
  (`readInstant`), even though truncation interacts with it; DESC sort makes the interaction
  benign (only oldest-history loss on first sync).

## Useful Commands

```bash
make test        # host swift test
make lint        # swiftlint --strict
xcodebuild test -project CoachApp.xcodeproj -scheme CoachKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'   # sim suite
```

## Uncertainty

- Whether `stop(query)` interrupts an in-flight `HKSampleQuery` result computation promptly
  on a wedged `healthd` — unresolvable off-device; hence the once-guarded resume (return
  immediately regardless) and the kept 20s abandoning backstop.
- Exact default limit value (10 000/type) — judgement call balancing watch-wearer heart-rate
  density vs POST size; named constant, documented, trivially adjustable.

## References

- `docs/artifacts/audits/AUDIT-2026-07-05.md` — Reliability lens, first-sync stall +
  unbounded probe findings (CR-3 lineage).
- `docs/artifacts/epics/18-run-on-device.md` — Phase 18.2 goal/criteria.
- Commit `15d74e1` — the 2026-06-18 partial fix this phase completes.
