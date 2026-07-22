import BriefRepository
import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import Testing

@testable import WeeklyFeature

/// Phase 20.3 — the Weekly tab honors the app's cache-first invariant: a tab re-appear over a `.ready`
/// plan for the current ISO week re-renders in place (no full-screen `.loading` reset, no fetch); only
/// an ISO-week rollover reloads. Plus the pull-to-refresh gate (`WeeklyViewState.isReady`).
@MainActor
struct WeeklyCacheFirstTests {
  @Test func test_task_reappearOverReadySameWeekPlan_keepsReady_noReload() async throws {
    // The Phase 20.3 acceptance lock: re-entering the tab with a `.ready` plan for the current ISO week
    // must NOT reset to full-screen `.loading` (cache-first honored) — and must not re-fetch at all.
    let plan = try WeeklyTestSupport.deloadPlan(cached: true) // isoWeek "2026-W24"
    let zones = WeeklyTestSupport.sampleZones()
    let fetchCalls = LockIsolated(0)
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) { // W24
      $0.profileRepository.zones = { zones }
      $0.briefRepository.weeklyBrief = { _, _ in
        fetchCalls.withValue { $0 += 1 }
        return plan
      }
    }

    await store.send(.task) { $0.weeklyState = .loading } // first appear loads
    await store.receive(\.weeklyResolved) {
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.nutrition = WeeklyNutritionComponent.make(from: plan)
      $0.adherence = AdherenceComponent.make(from: plan.nutrition)
      $0.weeklyState = .ready(plan, .cached)
    }
    await store.receive(\.zonesResolved) { $0.zones = zones }

    // Re-appear: the exhaustive TestStore proves no state mutation AND no effect (no received actions).
    await store.send(.task)
    #expect(fetchCalls.value == 1, "a same-week re-appear never re-fetches — the rendered plan stands")
    #expect(store.state.weeklyState == .ready(plan, .cached), "no .loading reset on re-appear")
  }

  @Test func test_task_reappearAfterISOWeekRollover_reloads() async throws {
    // A `.ready` plan that survived a week rollover (the tab stayed resident across Sunday→Monday) IS
    // reloaded on the next appear — the one re-appear case that may show `.loading` again.
    let plan = try WeeklyTestSupport.deloadPlan() // isoWeek "2026-W24"
    let zones = WeeklyTestSupport.sampleZones()
    let refreshArgs = LockIsolated<[Bool]>([])
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) { // W24
      $0.profileRepository.zones = { zones }
      $0.briefRepository.weeklyBrief = { _, refresh in
        refreshArgs.withValue { $0.append(refresh) }
        return plan
      }
    }

    await store.send(.task) { $0.weeklyState = .loading }
    await store.receive(\.weeklyResolved) {
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.nutrition = WeeklyNutritionComponent.make(from: plan)
      $0.adherence = AdherenceComponent.make(from: plan.nutrition)
      $0.weeklyState = .ready(plan, .fresh)
    }
    await store.receive(\.zonesResolved) { $0.zones = zones }

    // The Sofia clock crosses into 2026-W25 while the tab stays resident…
    store.dependencies.date = .constant(WeeklyTestSupport.sofiaMidday(2026, 6, 15)) // Monday of W25
    await store.send(.task) { $0.weeklyState = .loading } // …so the re-appear reloads
    await store.receive(\.weeklyResolved) { $0.weeklyState = .ready(plan, .fresh) }
    await store.receive(\.zonesResolved)
    #expect(refreshArgs.value == [false, false], "the rollover reload stays refresh: false — repo decides")
  }

  @Test func test_isReady_onlyForReadyCase() throws {
    // The pull-to-refresh gate: `.refreshable` attaches only over `.ready`, and the spinner-hold poll
    // exits the moment the state leaves `.ready`.
    let plan = try WeeklyTestSupport.deloadPlan()
    #expect(WeeklyViewState.idle.isReady == false)
    #expect(WeeklyViewState.loading.isReady == false)
    #expect(WeeklyViewState.error(.transientGenerationFailed).isReady == false)
    #expect(WeeklyViewState.ready(plan, .fresh).isReady == true)
  }

}
