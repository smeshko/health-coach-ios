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
/// (TASK-003). The rhythm + toggles (TASK-004) cases grow this suite; the Phase 20.3 cache-first
/// re-appear behaviour lives in `WeeklyCacheFirstTests`.
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
      $0.date = .constant(WeeklyTestSupport.sofiaMidday(2026, 6, 8)) // Monday of 2026-W24
    } operation: {
      WeeklyFeature().currentISOWeekKey
    }
    let w25 = withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(WeeklyTestSupport.sofiaMidday(2026, 6, 15)) // Monday of 2026-W25
    } operation: {
      WeeklyFeature().currentISOWeekKey
    }
    #expect(w24 == "2026-W24")
    #expect(w25 == "2026-W25")
    #expect(w24 != w25)
  }

  // MARK: - Get-or-cache fetch effect (TASK-003)

  @Test func test_task_coldOpen_landsReadyFresh() async throws {
    let plan = try WeeklyTestSupport.deloadPlan() // cached == false, isoWeek "2026-W24"
    let zones = WeeklyTestSupport.sampleZones()
    let refreshArgs = LockIsolated<[Bool]>([])
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) {
      $0.profileRepository.zones = { zones }
      $0.briefRepository.weeklyBrief = { _, refresh in
        refreshArgs.withValue { $0.append(refresh) }
        return plan
      }
    }

    await store.send(.task) { $0.weeklyState = .loading }
    await store.receive(\.weeklyResolved) { // the plan renders first (before zones)
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.nutrition = WeeklyNutritionComponent.make(from: plan)
      $0.adherence = AdherenceComponent.make(from: plan.nutrition)
      $0.weeklyState = .ready(plan, .fresh)
    }
    await store.receive(\.zonesResolved) { $0.zones = zones } // then zones hydrate
    #expect(refreshArgs.value == [false], "the appear path calls weeklyBrief once with refresh: false")
  }

  @Test func test_task_sameWeek_servesCache_neverRefreshTrue() async throws {
    let cached = try WeeklyTestSupport.deloadPlan(cached: true) // the repo stamps a same-week local hit
    let zones = WeeklyTestSupport.sampleZones()
    let refreshArgs = LockIsolated<[Bool]>([])
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) {
      $0.profileRepository.zones = { zones }
      $0.briefRepository.weeklyBrief = { _, refresh in
        refreshArgs.withValue { $0.append(refresh) }
        return cached
      }
    }

    await store.send(.task) { $0.weeklyState = .loading }
    await store.receive(\.weeklyResolved) {
      $0.rhythm = WeekRhythmComponent.rhythm(from: cached)
      $0.nutrition = WeeklyNutritionComponent.make(from: cached)
      $0.adherence = AdherenceComponent.make(from: cached.nutrition)
      $0.weeklyState = .ready(cached, .cached) // the cached flag drives .cached
    }
    await store.receive(\.zonesResolved) { $0.zones = zones }
    #expect(refreshArgs.value == [false], "a same-week open is refresh: false — never refresh: true")
  }

  @Test func test_weeklyBrief_throwsBriefError_landsError_thenRetrySucceeds() async throws {
    let plan = try WeeklyTestSupport.deloadPlan()
    let zones = WeeklyTestSupport.sampleZones()
    let shouldFail = LockIsolated(true)
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) {
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
      $0.nutrition = WeeklyNutritionComponent.make(from: plan)
      $0.adherence = AdherenceComponent.make(from: plan.nutrition)
      $0.weeklyState = .ready(plan, .fresh)
    }
    await store.receive(\.zonesResolved) { $0.zones = zones }
  }

  @Test func test_weeklyBrief_nonBriefErrorThrow_landsTerminalError_noHang() async throws {
    let zones = WeeklyTestSupport.sampleZones()
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) {
      $0.profileRepository.zones = { zones }
      $0.briefRepository.weeklyBrief = { _, _ in throw WeeklyTestSupport.Boom() }
    }

    await store.send(.task) { $0.weeklyState = .loading }
    // A non-BriefError throw maps to a retryable terminal — never a stuck .loading.
    await store.receive(\.weeklyFailed) { $0.weeklyState = .error(.transientGenerationFailed) }
  }

  @Test func test_zonesThrows_leavesNil_planStillReady() async throws {
    let plan = try WeeklyTestSupport.deloadPlan()
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) {
      $0.profileRepository.zones = { throw WeeklyTestSupport.Boom() }
      $0.briefRepository.weeklyBrief = { _, _ in plan }
    }

    await store.send(.task) { $0.weeklyState = .loading }
    await store.receive(\.weeklyResolved) {
      // The plan lands ready regardless of zones.
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.nutrition = WeeklyNutritionComponent.make(from: plan)
      $0.adherence = AdherenceComponent.make(from: plan.nutrition)
      $0.weeklyState = .ready(plan, .fresh)
    }
    await store.receive(\.zonesResolved) // nil (throw degraded) → merge no-op, zones stays nil
    #expect(store.state.zones == nil, "a throwing zones read is non-fatal — the plan still lands ready")
  }

  @Test func test_refreshTapped_debounces_singleRefreshTrueFetch() async throws {
    let plan = try WeeklyTestSupport.deloadPlan()
    let zones = WeeklyTestSupport.sampleZones()
    let clock = TestClock()
    let refreshArgs = LockIsolated<[Bool]>([])
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) {
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
    }
    await store.receive(\.weeklyResolved) {
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.nutrition = WeeklyNutritionComponent.make(from: plan)
      $0.adherence = AdherenceComponent.make(from: plan.nutrition)
      $0.weeklyState = .ready(plan, .fresh)
    }
    await store.receive(\.zonesResolved) { $0.zones = zones }
    #expect(refreshArgs.value == [true], "two rapid refreshTapped collapse to one refresh: true fetch")
  }

  @Test func test_newTask_cancelsInFlightFetch_onlySecondLands() async throws {
    let plan = try WeeklyTestSupport.deloadPlan()
    let zones = WeeklyTestSupport.sampleZones()
    let clock = TestClock()
    let weeklyCalls = LockIsolated(0)
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) {
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
      $0.nutrition = WeeklyNutritionComponent.make(from: plan)
      $0.adherence = AdherenceComponent.make(from: plan.nutrition)
      $0.weeklyState = .ready(plan, .fresh)
    }
    await store.receive(\.zonesResolved) { $0.zones = zones }
  }

  @Test func test_hungZones_doesNotBlockReadyPlan() async throws {
    // Review #2 regression lock: a parked profile read must NOT block the primary plan. weeklyBrief
    // returns immediately while zones() sleeps "forever"; the plan must land `.ready` with zones still
    // nil, and zones only hydrate once the parked read resumes.
    let plan = try WeeklyTestSupport.deloadPlan()
    let zones = WeeklyTestSupport.sampleZones()
    let clock = TestClock()
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) {
      $0.continuousClock = clock
      $0.profileRepository.zones = {
        try await clock.sleep(for: .seconds(3600)) // parked until the test releases it
        return zones
      }
      $0.briefRepository.weeklyBrief = { _, _ in plan }
    }

    await store.send(.task) { $0.weeklyState = .loading }
    await store.receive(\.weeklyResolved) { // the plan renders WHILE zones is still parked
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.nutrition = WeeklyNutritionComponent.make(from: plan)
      $0.adherence = AdherenceComponent.make(from: plan.nutrition)
      $0.weeklyState = .ready(plan, .fresh)
    }
    #expect(store.state.zones == nil, "the plan is ready before the parked zones read resolves")
    await clock.advance(by: .seconds(3600)) // release the parked zones → it hydrates after the fact
    await store.receive(\.zonesResolved) { $0.zones = zones }
  }

  // MARK: - Session groups (Phase 9.2 TASK-003)

  @Test func test_coreGroupToggled_flipsOnlyCore() async {
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) { _ in }
    #expect(store.state.isCoreExpanded == true)
    #expect(store.state.isExtrasExpanded == true)
    await store.send(.coreGroupToggled) { $0.isCoreExpanded = false }
    await store.send(.coreGroupToggled) { $0.isCoreExpanded = true }
  }

  @Test func test_extrasGroupToggled_flipsOnlyExtras() async {
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) { _ in }
    await store.send(.extrasGroupToggled) { $0.isExtrasExpanded = false }
    await store.send(.extrasGroupToggled) { $0.isExtrasExpanded = true }
  }

  @Test func test_groupFlags_surviveRefreshedPlan() async throws {
    // The collapse flags are pure UI state held outside `WeeklyViewState`, so a re-supplied plan (a
    // refreshed week landing a new `.ready`) leaves them untouched.
    let plan = try WeeklyTestSupport.deloadPlan()
    let zones = WeeklyTestSupport.sampleZones()
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) {
      $0.profileRepository.zones = { zones }
      $0.briefRepository.weeklyBrief = { _, _ in plan }
    }
    await store.send(.coreGroupToggled) { $0.isCoreExpanded = false }
    await store.send(.extrasGroupToggled) { $0.isExtrasExpanded = false }
    await store.send(.task) { $0.weeklyState = .loading }
    await store.receive(\.weeklyResolved) {
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.nutrition = WeeklyNutritionComponent.make(from: plan)
      $0.adherence = AdherenceComponent.make(from: plan.nutrition)
      $0.weeklyState = .ready(plan, .fresh)
    }
    await store.receive(\.zonesResolved) { $0.zones = zones }
    #expect(store.state.isCoreExpanded == false, "group flags survive a re-supplied plan")
    #expect(store.state.isExtrasExpanded == false)
  }
}
