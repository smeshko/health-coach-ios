# TASK-001: HealthReadBounds + HealthKitReadError interface; signature + call-site adaptation

Depends on: None
Suggested commit: `feat(healthkit): express bounded reads (limit + since + timeout) in the interface`

## Goal

The read interface can only express bounded reads: `deltaSamples` takes a `HealthReadBounds`
(since-floor + per-type row limit + timeout), and a whole-read timeout has a typed error.

## Files

- `Sources/Clients/HealthKitClient/Interface/HealthKitClient.swift` —
  - `public struct HealthReadBounds: Sendable, Equatable { public var since: Date; public var
    limitPerType: Int; public var timeout: Duration }` with
    `public static func since(_ date: Date) -> HealthReadBounds` applying the documented
    defaults (`limitPerType: 10_000`, `timeout: .seconds(15)`); memberwise `public init` for
    explicit call sites.
  - `public enum HealthKitReadError: Error, Equatable { case timedOut }` — thrown only for a
    whole-read timeout; the per-category empty-slice contract is unchanged.
  - `deltaSamples` becomes `@Sendable (_ bounds: HealthReadBounds) async throws ->
    HealthSampleSet` (single argument — positional `{ _ in }` stubs keep compiling).
  - `testValue`: `{ bounds in CannedHealthSamples.cannedSampleSet().filtered(after:
    bounds.since) }`.
- `Sources/Clients/HealthKitClient/Live/HealthKitClientLive.swift` — mechanical: live arm
  forwards `bounds` to `liveDeltaSamples(box:bounds:)` (implemented properly in TASK-002 —
  for this commit thread `bounds.since` through and keep behaviour identical); `#else` stub
  arm `{ _ in .empty }` unchanged.
- `Sources/Clients/HealthKitClient/Live/HKDeltaReads.swift` — signature only
  (`since: Date` → `bounds: HealthReadBounds`, use `bounds.since`); real bounding is TASK-002.
- `Sources/Repositories/SyncRepository/Live/SyncRepository+Live.swift:67` — mechanical:
  `healthKit.deltaSamples(.since(anchorDate(anchor)))` (real wiring decisions in TASK-003).
- `Sources/Features/OnboardingFeature/Sources/HealthKitPriming.swift:106` — mechanical:
  `deltaSamples(.since(.distantPast))` (probe semantics unchanged; 18.3 owns the rework).
- `Sources/Clients/HealthKitClient/Tests/` — new `HealthReadBoundsTests.swift`: defaults,
  `since(_:)` factory, testValue honors `bounds.since` (adapt `HealthSampleSetFilterTests`
  if it constructs the client).

## Acceptance

- [ ] Package compiles with NO unbounded read expressible (`deltaSamples(Date)` is gone).
- [ ] `HealthReadBounds.since(d)` carries `since == d`, `limitPerType == 10_000`,
  `timeout == .seconds(15)` (pinned by test — these are the app-wide read bounds).
- [ ] `testValue.deltaSamples(.since(d))` filters canned samples after `d` (existing filter
  behaviour preserved).
- [ ] `make test` green (feature-test stubs `{ _ in }` untouched and compiling).

Evidence: `swift test --filter HealthKitClient` + full `swift test` output green.

## Steps

### RED
- [ ] `HealthReadBoundsTests` for defaults/factory/testValue filtering — fails to compile.

### GREEN
- [ ] Add the types, change the signature, adapt the five listed call sites mechanically.

### REFACTOR
- [ ] Doc comments: bounds contract on the interface (limit is per-type; timeout is
  whole-read; `.timedOut` is the only new error), `make lint` clean.

## Notes

Do NOT implement limiting/cancellation/timeout here — this commit is the interface + compile
ripple only, so TASK-002's live diff stays reviewable. Keep `HealthDataCategory`/payload
types untouched.
