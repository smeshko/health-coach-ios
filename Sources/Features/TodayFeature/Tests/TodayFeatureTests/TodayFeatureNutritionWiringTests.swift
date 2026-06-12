import Clocks
import CoachCore
import ComposableArchitecture
import DomainModels
import SampleData
import SessionFeature
import SyncRepository
import Testing

@testable import TodayFeature

/// `TestStore` coverage that the **loaded `ready` brief** carries the nutrition content the Today nutrition
/// area derives (Phase 8.5). The two sub-components are render-only and constructed **inline** from the
/// `.ready` brief in `TodayView` (the `SafetyRestComponent` precedent — no parent state / reducer scope), so
/// the wiring contract is: once the orchestration resolves `.ready`, that brief exposes the `macroFocus` +
/// `intakeYesterday` the inline `NutritionComponent` / `YesterdayIntakeComponent` consume. Reached through
/// the `.ready` case, for a logged brief and the `.dailyBriefNoFood` empty case.
@MainActor
struct TodayFeatureNutritionWiringTests {
  /// A no-food brief (whole-null `intakeYesterday`) with `cached` pinned — captured as a `let` so the
  /// `@Sendable` dependency stub holds an immutable value (Swift 6 strict concurrency).
  private static let noFoodBrief: DomainModels.DailyBrief = {
    var brief = SampleData.dailyBriefNoFood
    brief.cached = false
    return brief
  }()

  @Test func test_readyLoggedBrief_derivesNutritionTarget_andLoggedYesterday() async throws {
    let now = sofiaInstant()
    let fresh = sampleBrief(cached: false) // green — a logged `intakeYesterday`
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in fresh }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._zonesResolved) { $0.zones = sampleZones() }
    await store.receive(\._briefResolved) {
      $0.briefState = .ready(fresh, .fresh)
      $0.readiness = ReadinessComponent.State(readiness: fresh.readiness)
      $0.session = expectedSessionState(fresh, zones: sampleZones())
    }

    // The nutrition area derives from the `.ready` brief: the target panel + the logged yesterday recap.
    guard case let .ready(readyBrief, _) = store.state.briefState else {
      Issue.record("expected .ready after a successful orchestration")
      return
    }
    #expect(NutritionComponent.State(brief: readyBrief).macroFocus == fresh.macroFocus)
    let intake = try #require(readyBrief.intakeYesterday)
    #expect(YesterdayIntakeComponent.State(intakeYesterday: intake).display == .logged(intake))
  }

  @Test func test_readyNoFoodBrief_derivesEmptyYesterday_targetStillPresent() async {
    let now = sofiaInstant()
    let noFood = Self.noFoodBrief
    let store = TestStore(initialState: TodayFeature.State()) {
      TodayFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(now)
      $0.continuousClock = ImmediateClock()
      $0.checkInRepository.current = { _ in sampleCheckIn() }
      $0.syncRepository.sync = { sampleSyncResult() }
      $0.briefRepository.dailyBrief = { _ in noFood }
      $0.profileRepository.zones = { sampleZones() }
    }

    await store.send(.onAppOpen)
    await store.receive(\._syncStarted) { $0.briefState = .syncing }
    await store.receive(\._generating) {
      $0.lastSyncedAt = now
      $0.briefState = .generating
    }
    await store.receive(\._zonesResolved) { $0.zones = sampleZones() }
    await store.receive(\._briefResolved) {
      $0.briefState = .ready(noFood, .fresh)
      $0.readiness = ReadinessComponent.State(readiness: noFood.readiness)
      $0.session = expectedSessionState(noFood, zones: sampleZones())
    }

    guard case let .ready(readyBrief, _) = store.state.briefState else {
      Issue.record("expected .ready after a successful orchestration")
      return
    }
    // Whole-null intake → the empty recap; the always-present target panel still renders.
    #expect(readyBrief.intakeYesterday == nil)
    #expect(YesterdayIntakeComponent.State(intakeYesterday: readyBrief.intakeYesterday).display == .empty)
    #expect(NutritionComponent.State(brief: readyBrief).macroFocus == noFood.macroFocus)
  }
}
