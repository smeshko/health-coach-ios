import BriefRepository
import Clocks
import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import ProfileRepository
import SampleData
import Testing

@testable import WeeklyFeature

/// The target/harness smoke test + the new-ISO-week detection (TASK-002) + the get-or-cache fetch effect
/// (TASK-003). The rhythm + toggles (TASK-004) cases grow this suite.
///
/// `.serialized` because the `@Shared(.appStorage)` watermark is process-global app state — parallel tests
/// would race on it; serial execution + a per-test nil reset (`makeStore`) gives each test a clean baseline.
@Suite(.serialized)
@MainActor
struct WeeklyFeatureTests {
  @Test func test_initialState_isIdle() {
    let state = WeeklyFeature.State()
    #expect(state.weeklyState == .idle)
  }

  // MARK: - New-ISO-week detection (TASK-002)

  @Test func test_isoWeekKey_zeroPadsAndHandlesYearBoundary() {
    #expect(isoWeekKey(ISOWeek(year: 2026, week: 3)) == "2026-W03")
    // The ISO year-numbering boundary: 2026 is a 53-week ISO year; its W53 and the next ISO year's W01.
    #expect(isoWeekKey(ISOWeek(year: 2026, week: 52)) == "2026-W52")
    #expect(isoWeekKey(ISOWeek(year: 2026, week: 53)) == "2026-W53")
    #expect(isoWeekKey(ISOWeek(year: 2027, week: 1)) == "2027-W01")
  }

  @Test func test_currentISOWeekKey_flipsAcrossSofiaWeeks() {
    // Two instants on different Sofia ISO weeks → two distinct keys (deterministic).
    let w24 = withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.sofiaMidday(2026, 6, 8)) // Monday of 2026-W24
    } operation: {
      WeeklyFeature().currentISOWeekKey
    }
    let w25 = withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.sofiaMidday(2026, 6, 15)) // Monday of 2026-W25
    } operation: {
      WeeklyFeature().currentISOWeekKey
    }
    #expect(w24 == "2026-W24")
    #expect(w25 == "2026-W25")
    #expect(w24 != w25)
  }

  @Test func test_isNewWeek_predicate() {
    withDependencies {
      // A fresh in-memory appStorage suite so the watermark never leaks between tests / real UserDefaults.
      $0.defaultAppStorage = UserDefaults(suiteName: "weekly-isnewweek-\(UUID().uuidString)")!
      $0.useEuropeSofia()
      $0.date = .constant(Self.sofiaMidday(2026, 6, 8))
    } operation: {
      let feature = WeeklyFeature()
      let state = WeeklyFeature.State()
      #expect(state.lastSeenISOWeek == nil)
      #expect(feature.isNewWeek(state) == true) // nil watermark → new
      state.$lastSeenISOWeek.withLock { $0 = "2025-W01" }
      #expect(feature.isNewWeek(state) == true) // differs → new
      state.$lastSeenISOWeek.withLock { $0 = feature.currentISOWeekKey }
      #expect(feature.isNewWeek(state) == false) // matches → not new
    }
  }

  // MARK: - Get-or-cache fetch effect (TASK-003)

  @Test func test_task_fetchOnNewWeek_landsReadyFresh() async throws {
    let plan = try Self.deloadPlan() // cached == false, isoWeek "2026-W24"
    let zones = Self.sampleZones()
    let refreshArgs = LockIsolated<[Bool]>([])
    let store = Self.makeStore(date: Self.sofiaMidday(2026, 6, 8)) {
      $0.profileRepository.zones = { zones }
      $0.briefRepository.weeklyBrief = { _, refresh in
        refreshArgs.withValue { $0.append(refresh) }
        return plan
      }
    }

    await store.send(.task) { $0.weeklyState = .loading }
    await store.receive(\.weeklyResolved) { // the plan renders first (before zones)
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.weeklyState = .ready(plan, .fresh)
      $0.$lastSeenISOWeek.withLock { $0 = plan.isoWeek }
    }
    await store.receive(\.zonesResolved) { $0.zones = zones } // then zones hydrate
    #expect(refreshArgs.value == [false], "the appear path calls weeklyBrief once with refresh: false")
    #expect(store.state.lastSeenISOWeek == plan.isoWeek)
  }

  @Test func test_task_sameWeek_servesCache_neverRefreshTrue() async throws {
    let cached = try Self.deloadPlan(cached: true) // the repo stamps a same-week local hit
    let zones = Self.sampleZones()
    let refreshArgs = LockIsolated<[Bool]>([])
    let store = Self.makeStore(date: Self.sofiaMidday(2026, 6, 8)) {
      $0.profileRepository.zones = { zones }
      $0.briefRepository.weeklyBrief = { _, refresh in
        refreshArgs.withValue { $0.append(refresh) }
        return cached
      }
    }

    await store.send(.task) { $0.weeklyState = .loading }
    await store.receive(\.weeklyResolved) {
      $0.rhythm = WeekRhythmComponent.rhythm(from: cached)
      $0.weeklyState = .ready(cached, .cached) // the cached flag drives .cached
      $0.$lastSeenISOWeek.withLock { $0 = cached.isoWeek }
    }
    await store.receive(\.zonesResolved) { $0.zones = zones }
    #expect(refreshArgs.value == [false], "a same-week open is refresh: false — never refresh: true")
  }

  @Test func test_weeklyBrief_throwsBriefError_landsError_thenRetrySucceeds() async throws {
    let plan = try Self.deloadPlan()
    let zones = Self.sampleZones()
    let shouldFail = LockIsolated(true)
    let store = Self.makeStore(date: Self.sofiaMidday(2026, 6, 8)) {
      $0.profileRepository.zones = { zones }
      $0.briefRepository.weeklyBrief = { _, _ in
        if shouldFail.value { throw BriefError.transientGenerationFailed }
        return plan
      }
    }

    await store.send(.task) { $0.weeklyState = .loading }
    await store.receive(\.weeklyFailed) { $0.weeklyState = .error(.transientGenerationFailed) }

    shouldFail.setValue(false)
    await store.send(.retryTapped) { $0.weeklyState = .loading }
    await store.receive(\.weeklyResolved) {
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.weeklyState = .ready(plan, .fresh)
      $0.$lastSeenISOWeek.withLock { $0 = plan.isoWeek }
    }
    await store.receive(\.zonesResolved) { $0.zones = zones }
  }

  @Test func test_weeklyBrief_nonBriefErrorThrow_landsTerminalError_noHang() async throws {
    let zones = Self.sampleZones()
    let store = Self.makeStore(date: Self.sofiaMidday(2026, 6, 8)) {
      $0.profileRepository.zones = { zones }
      $0.briefRepository.weeklyBrief = { _, _ in throw Self.Boom() }
    }

    await store.send(.task) { $0.weeklyState = .loading }
    // A non-BriefError throw maps to a retryable terminal — never a stuck .loading.
    await store.receive(\.weeklyFailed) { $0.weeklyState = .error(.transientGenerationFailed) }
  }

  @Test func test_zonesThrows_leavesNil_planStillReady() async throws {
    let plan = try Self.deloadPlan()
    let store = Self.makeStore(date: Self.sofiaMidday(2026, 6, 8)) {
      $0.profileRepository.zones = { throw Self.Boom() }
      $0.briefRepository.weeklyBrief = { _, _ in plan }
    }

    await store.send(.task) { $0.weeklyState = .loading }
    await store.receive(\.weeklyResolved) {
      // The plan lands ready regardless of zones.
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.weeklyState = .ready(plan, .fresh)
      $0.$lastSeenISOWeek.withLock { $0 = plan.isoWeek }
    }
    await store.receive(\.zonesResolved) // nil (throw degraded) → merge no-op, zones stays nil
    #expect(store.state.zones == nil, "a throwing zones read is non-fatal — the plan still lands ready")
  }

  @Test func test_refreshTapped_debounces_singleRefreshTrueFetch() async throws {
    let plan = try Self.deloadPlan()
    let zones = Self.sampleZones()
    let clock = TestClock()
    let refreshArgs = LockIsolated<[Bool]>([])
    let store = Self.makeStore(date: Self.sofiaMidday(2026, 6, 8)) {
      $0.continuousClock = clock
      $0.profileRepository.zones = { zones }
      $0.briefRepository.weeklyBrief = { _, refresh in
        refreshArgs.withValue { $0.append(refresh) }
        return plan
      }
    }

    await store.send(.refreshTapped)
    await store.send(.refreshTapped) // resets the debounce window — the first never fires
    await clock.advance(by: WeeklyFeature.refreshDebounceDuration)
    await store.receive(\.refreshRequested) {
      $0.weeklyState = .loading
      // `@Shared` is a reference: the refreshRequested → fetch → weeklyResolved chain settles before this
      // first receive, so the watermark is already written here (it's asserted at the first receive that
      // observes the change, not the reducer step that wrote it).
      $0.$lastSeenISOWeek.withLock { $0 = plan.isoWeek }
    }
    await store.receive(\.weeklyResolved) {
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.weeklyState = .ready(plan, .fresh)
    }
    await store.receive(\.zonesResolved) { $0.zones = zones }
    #expect(refreshArgs.value == [true], "two rapid refreshTapped collapse to one refresh: true fetch")
  }

  @Test func test_newTask_cancelsInFlightFetch_onlySecondLands() async throws {
    let plan = try Self.deloadPlan()
    let zones = Self.sampleZones()
    let clock = TestClock()
    let weeklyCalls = LockIsolated(0)
    let store = Self.makeStore(date: Self.sofiaMidday(2026, 6, 8)) {
      $0.continuousClock = clock
      $0.profileRepository.zones = { zones }
      $0.briefRepository.weeklyBrief = { _, _ in
        let callIndex = weeklyCalls.withValue { $0 += 1; return $0 }
        // The first run parks in weeklyBrief (before sending the plan) so a newer trigger cancels it
        // mid-flight; the cancelled clock.sleep throws, the run aborts, and TCA drops its (would-be) sends.
        if callIndex == 1 { try await clock.sleep(for: .seconds(60)) }
        return plan
      }
    }

    await store.send(.task) { $0.weeklyState = .loading } // first run parks in weeklyBrief()
    await store.send(.task) // already .loading; cancelInFlight cancels the first run
    await store.receive(\.weeklyResolved) { // only the second run's plan lands
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.weeklyState = .ready(plan, .fresh)
      $0.$lastSeenISOWeek.withLock { $0 = plan.isoWeek }
    }
    await store.receive(\.zonesResolved) { $0.zones = zones }
  }

  // MARK: - Helpers

  /// A test store with the Europe/Sofia frame pinned, a fresh appStorage suite (so the `@Shared` watermark
  /// never leaks between parallel tests / real UserDefaults), and an `ImmediateClock` by default (tests
  /// that drive the debounce/cancellation override `\.continuousClock` with a `TestClock`).
  ///
  /// The unique suite is bound around the **initialState** evaluation too: `TestStore` evaluates its
  /// `initialState` autoclosure outside its own `withDependencies`, so `WeeklyFeature.State()`'s
  /// `@Shared(.appStorage)` would otherwise bind to the ambient (process-shared) store and contaminate
  /// across parallel tests. Wrapping the whole construction in `withDependencies { defaultAppStorage }`
  /// pins both the initial state and the reducer to the same isolated suite.
  private static func makeStore(
    date: Date,
    _ prepare: @escaping (inout DependencyValues) -> Void
  ) -> TestStoreOf<WeeklyFeature> {
    // A unique suite per test isolates the `@Shared(.appStorage)` watermark (distinct `AppStorageKeyID`).
    // `TestStore` evaluates its `initialState` autoclosure inside this same `withDependencies` scope, so
    // the initial state and the reducer share one dependency context (and one `PersistentReferences`
    // cache) bound to this suite — no split-context contamination.
    let suiteName = "weekly-tests-\(UUID().uuidString)"
    let suite = UserDefaults(suiteName: suiteName)!
    suite.removePersistentDomain(forName: suiteName)
    return TestStore(initialState: WeeklyFeature.State()) {
      WeeklyFeature()
    } withDependencies: {
      $0.defaultAppStorage = suite
      $0.useEuropeSofia()
      $0.date = .constant(date)
      $0.continuousClock = ImmediateClock()
      prepare(&$0)
    }
  }

  private static func deloadPlan(cached: Bool = false) throws -> DomainModels.WeeklyPlan {
    var plan = try SampleData.weeklyPlan(.weeklyPlanDeload).domain
    plan.cached = cached
    return plan
  }

  private static func sampleZones() -> DomainModels.Zones {
    SampleData.sampleProfile.zones
  }

  /// A non-`BriefError` error to exercise the fetch catch-all (a propagated 401 / unexpected throw).
  private struct Boom: Error {}

  /// A Europe/Sofia midday instant, host-timezone-independent (mirrors WeeklyCachePolicyTests' helper).
  private static func sofiaMidday(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Sofia")!
    return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
  }
}
