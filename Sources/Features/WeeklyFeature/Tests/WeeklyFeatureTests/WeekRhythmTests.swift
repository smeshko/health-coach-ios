import ComposableArchitecture
import DesignSystem
import DomainModels
import Foundation
import Testing

@testable import WeeklyFeature

/// The week-rhythm derivation (TASK-004) + the pure UI toggles + the deload tone treatment. The derivation
/// places the plan's suggested sessions onto the Mon…Sun dot-row with the pinned classification (the
/// 2026-06-10 3-way legend folds strength into hard/easy by `isHardDay`; fill = core-vs-extra tier).
///
/// `.serialized` because the zones-retention case drives the `@Shared(.appStorage)` watermark (process
/// -global app state) — serial execution + the per-test isolated suite keep it from racing.
@Suite(.serialized)
@MainActor
struct WeekRhythmTests {
  // MARK: - Derivation

  @Test func test_rhythm_placesHardEasyRest_byDayAndTier() {
    // tue: easy core; thu: hard core; (no other suggested days) → the rest are rest.
    let plan = Self.plan(
      core: [
        Self.session(.easyRun, tier: .core, isHardDay: false, day: .tue),
        Self.session(.strengthFull, tier: .core, isHardDay: true, day: .thu),
      ],
      extras: [Self.session(.mobility, tier: .extra, isHardDay: false, day: nil)] // nil day → no dot
    )
    let rhythm = WeekRhythmComponent.rhythm(from: plan)
    #expect(rhythm.days == [
      .rest, // mon
      .easy(core: true), // tue
      .rest, // wed
      .hard(core: true), // thu
      .rest, // fri
      .rest, // sat
      .rest, // sun
    ])
    #expect(rhythm.budgets == plan.budgets)
  }

  @Test func test_rhythm_extraOnlyDay_isOutlined_andHardWinsCollision() {
    // mon: an EXTRA easy session → outlined easy; wed: a core easy + an extra hard on the same day →
    // hard wins the character, core wins the fill.
    let plan = Self.plan(
      core: [Self.session(.easyRun, tier: .core, isHardDay: false, day: .wed)],
      extras: [
        Self.session(.glutePrehab, tier: .extra, isHardDay: false, day: .mon),
        Self.session(.threshold, tier: .extra, isHardDay: true, day: .wed),
      ]
    )
    let rhythm = WeekRhythmComponent.rhythm(from: plan)
    #expect(rhythm.days[0] == .easy(core: false), "an extra-only day is outlined")
    #expect(rhythm.days[2] == .hard(core: true), "hard wins the character, core wins the fill")
  }

  @Test func test_rhythm_nilSuggestedDay_neverCrashes_placesNoDot() {
    let plan = Self.plan(
      core: [Self.session(.longRun, tier: .core, isHardDay: false, day: nil)],
      extras: []
    )
    let rhythm = WeekRhythmComponent.rhythm(from: plan)
    #expect(rhythm.days == Array(repeating: .rest, count: 7), "a nil suggestedDay places no dot")
  }

  // MARK: - UI toggles

  @Test func test_sectionSelected_flipsOnlySelectedSection() async {
    let store = TestStore(initialState: WeeklyFeature.State()) { WeeklyFeature() }
    #expect(store.state.selectedSection == .exercise)
    await store.send(.sectionSelected(.nutrition)) { $0.selectedSection = .nutrition }
    await store.send(.sectionSelected(.exercise)) { $0.selectedSection = .exercise }
  }

  @Test func test_planCardToggled_flipsOnlyExpansion() async {
    let store = TestStore(initialState: WeeklyFeature.State()) { WeeklyFeature() }
    #expect(store.state.isPlanCardExpanded == true)
    await store.send(.planCardToggled) { $0.isPlanCardExpanded = false }
    await store.send(.planCardToggled) { $0.isPlanCardExpanded = true }
  }

  // MARK: - Deload tone treatment

  @Test func test_scheduleFraming_deloadSelectsEasyOnPurpose() {
    #expect(WeeklyFeature.scheduleFraming(deload: true) == "easy on purpose")
    #expect(WeeklyFeature.scheduleFraming(deload: false) == "a menu, not a schedule")
  }

  // MARK: - Zones merge (keep-last-known, review)

  /// A later load whose `zones()` throws keeps the last-known zones (the TodayFeature `mergeZones`
  /// semantics — zones are stable profile constants, so a transient read failure must not blank the bpm
  /// ranges). `zonesResolved(nil)` is a deliberate no-op, not a clear.
  @Test func test_zonesRetainedAcrossFailedRefresh() async throws {
    let plan = try WeeklyTestSupport.deloadPlan()
    let zones = WeeklyTestSupport.sampleZones()
    let zonesThrows = LockIsolated(false)
    let store = WeeklyTestSupport.makeStore(date: WeeklyTestSupport.sofiaMidday(2026, 6, 8)) {
      $0.profileRepository.zones = {
        if zonesThrows.value { throw WeeklyTestSupport.Boom() }
        return zones
      }
      $0.briefRepository.weeklyBrief = { _, _ in plan }
    }
    await store.send(.task) { $0.weeklyState = .loading }
    await store.receive(\.weeklyResolved) {
      $0.rhythm = WeekRhythmComponent.rhythm(from: plan)
      $0.nutrition = WeeklyNutritionComponent.make(from: plan)
      $0.adherence = AdherenceComponent.make(from: plan.nutrition)
      $0.weeklyState = .ready(plan, .fresh)
    }
    await store.receive(\.zonesResolved) { $0.zones = zones }

    zonesThrows.setValue(true)
    // Roll the Sofia clock into the next ISO week so the re-appear is a genuine reload (a same-week
    // `.task` over `.ready` is now a cache-first no-op, Phase 20.3).
    store.dependencies.date = .constant(WeeklyTestSupport.sofiaMidday(2026, 6, 15))
    await store.send(.task) { $0.weeklyState = .loading }
    await store.receive(\.weeklyResolved) { $0.weeklyState = .ready(plan, .fresh) }
    await store.receive(\.zonesResolved) // nil → no-op; the prior zones are retained
    #expect(store.state.zones == zones, "a failed zones refresh keeps the last-known map")
  }

  // MARK: - Fixtures

  private static func session(
    _ card: Card, tier: Tier, isHardDay: Bool, day: Weekday?
  ) -> PlannedSession {
    PlannedSession(card: card, tier: tier, intensity: .easy, isHardDay: isHardDay, suggestedDay: day)
  }

  private static func plan(core: [PlannedSession], extras: [PlannedSession]) -> WeeklyPlan {
    WeeklyPlan(
      isoWeek: "2026-W24",
      weekStart: Date(timeIntervalSince1970: 0),
      budgets: WeeklyBudgets(hardDays: 1, strengthSessions: 1, longRunKm: nil, deload: false),
      core: core,
      extras: extras,
      targets: WeeklyTargets(easyRunRatio: 0.8, strengthSessions: 1, hardDays: 1, cadenceSpm: 178),
      nutrition: WeeklyNutrition(
        proteinG: 170, fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.5,
        avgCaloriesKcal: 2400
      ),
      constantsRecomputed: false,
      generatedAt: Date(timeIntervalSince1970: 0),
      cached: false
    )
  }
}
