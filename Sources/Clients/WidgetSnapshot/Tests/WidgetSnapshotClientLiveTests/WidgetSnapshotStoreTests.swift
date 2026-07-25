import CoachCore
import DomainModels
import Foundation
import Testing
import WidgetSnapshotClient
import WidgetSnapshotClientLive

/// `WidgetSnapshotStore` file-store + merge semantics (Phase 21.1 TASK-002): the atomic write/read
/// round-trip, the section-preserving daily merge (the no-schema-surgery guarantee 21.2/21.4/21.5
/// rely on), the cross-day stale-selection drop, and corrupt-file degradation. All against a fresh
/// temp directory — never the real App Group container.
@Suite("WidgetSnapshotStore")
struct WidgetSnapshotStoreTests {
  // MARK: - Fixtures

  private func makeStore() -> WidgetSnapshotStore {
    WidgetSnapshotStore(
      directoryURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    )
  }

  private func sofiaInstant(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0
  ) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    // Force-unwrap: fixed valid components against the fixed europeSofia calendar.
    return Calendar.europeSofia.date(from: components)!
  }

  private func makeBrief(date: Date) -> DailyBrief {
    DailyBrief(
      date: date,
      readiness: Readiness(score: 82, band: .green),
      safetyGate: SafetyGate(triggered: false),
      session: SessionBlock(
        card: .easyRun, intensity: .easy, zoneTarget: .z2, durationMinLow: 40, durationMinHigh: 50
      ),
      skipOk: false,
      macroFocus: MacroFocus(
        dayType: .moderate, caloriesKcal: 2400, proteinG: 150, carbsG: 280,
        fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.0
      ),
      intakeYesterday: IntakeSummary(
        date: date.addingTimeInterval(-86_400),
        caloriesKcal: 2200,
        vsTarget: IntakeVsTarget(caloriesPct: 0.92, proteinHit: true)
      ),
      generatedAt: date.addingTimeInterval(7 * 3600),
      cached: false
    )
  }

  private func makeExisting(
    dailyDate: Date, selectedSession: SessionBlock?
  ) -> WidgetSnapshot {
    WidgetSnapshot(
      generatedAt: dailyDate,
      daily: WidgetDailySnapshot(
        date: dailyDate,
        readiness: Readiness(score: 60, band: .amber),
        safetyGate: SafetyGate(triggered: false),
        plannedSession: SessionBlock(
          card: .threshold, intensity: .quality, durationMinLow: 30, durationMinHigh: 40
        ),
        selectedSession: selectedSession,
        macroFocus: MacroFocus(
          dayType: .hard, caloriesKcal: 2700, proteinG: 160, carbsG: 320,
          fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.5
        )
      ),
      weekly: WidgetWeeklySnapshot(
        isoWeek: "2026-W30",
        budgets: WeeklyBudgets(hardDays: 2, strengthSessions: 3, deload: false),
        targets: WeeklyTargets(easyRunRatio: 0.8, strengthSessions: 3, hardDays: 2, cadenceSpm: 170)
      ),
      checkIn: WidgetCheckInState(date: dailyDate, logged: true, source: .app)
    )
  }

  private let alternativeSession = SessionBlock(
    card: .strides, intensity: .quality, durationMinLow: 20, durationMinHigh: 30
  )

  /// A domain weekly plan whose `extras` are non-empty — the weekly merge must drop them.
  private func makeWeeklyPlan(isoWeek: String, weekStart: Date) -> DomainModels.WeeklyPlan {
    WeeklyPlan(
      isoWeek: isoWeek,
      weekStart: weekStart,
      budgets: WeeklyBudgets(hardDays: 2, strengthSessions: 3, longRunKm: 14, deload: false),
      core: [
        PlannedSession(
          card: .longRun, tier: .core, intensity: .easy, isHardDay: false, suggestedDay: .sat
        ),
        PlannedSession(
          card: .threshold, tier: .core, intensity: .quality, isHardDay: true, suggestedDay: .tue
        ),
      ],
      extras: [
        PlannedSession(card: .mobility, tier: .extra, intensity: .recovery, isHardDay: false),
      ],
      targets: WeeklyTargets(
        totalRunKm: 30, easyRunRatio: 0.8, strengthSessions: 3, hardDays: 2, cadenceSpm: 170
      ),
      nutrition: WeeklyNutrition(
        proteinG: 150, fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.0,
        avgCaloriesKcal: 2400
      ),
      constantsRecomputed: false,
      generatedAt: weekStart.addingTimeInterval(7 * 3600),
      cached: false
    )
  }

  // MARK: - Write / read round-trip

  @Test func test_writeThenRead_returnsIdenticalSnapshot() throws {
    let store = makeStore()
    let snapshot = makeExisting(
      dailyDate: sofiaInstant(2026, 7, 24), selectedSession: alternativeSession
    )

    try store.write(snapshot)

    #expect(store.read() == snapshot)
  }

  @Test func test_read_missingFile_returnsNil() {
    #expect(makeStore().read() == nil)
  }

  @Test func test_read_corruptFile_returnsNil() throws {
    let store = makeStore()
    // Write a valid file first so the directory exists, then corrupt it in place.
    try store.write(makeExisting(dailyDate: sofiaInstant(2026, 7, 24), selectedSession: nil))
    try Data("not json {{{".utf8).write(to: store.fileURL)

    #expect(store.read() == nil)
  }

  // MARK: - Daily merge

  @Test func test_mergeDailyBrief_sameDay_replacesDailyPreservesSectionsAndSelection() throws {
    let store = makeStore()
    let day = sofiaInstant(2026, 7, 24)
    let existing = makeExisting(dailyDate: day, selectedSession: alternativeSession)
    try store.write(existing)

    // A same-Sofia-day refresh (later wall-clock instant, same day).
    let brief = makeBrief(date: day)
    let generatedAt = sofiaInstant(2026, 7, 24, 9, 30)
    try store.mergeDailyBrief(brief, generatedAt: generatedAt)

    let merged = try #require(store.read())
    #expect(merged.generatedAt == generatedAt)
    #expect(merged.schemaVersion == WidgetSnapshot.currentSchemaVersion)
    // Daily fields replaced by the fresh brief…
    #expect(merged.daily?.readiness == brief.readiness)
    #expect(merged.daily?.plannedSession == brief.session)
    #expect(merged.daily?.macroFocus == brief.macroFocus)
    #expect(merged.daily?.intakeYesterday == brief.intakeYesterday)
    // …the same-day selection survives, and the sibling sections are untouched.
    #expect(merged.daily?.selectedSession == alternativeSession)
    #expect(merged.weekly == existing.weekly)
    #expect(merged.checkIn == existing.checkIn)
  }

  @Test func test_mergeDailyBrief_newSofiaDay_dropsStaleSelection() throws {
    let store = makeStore()
    let existing = makeExisting(
      dailyDate: sofiaInstant(2026, 7, 23), selectedSession: alternativeSession
    )
    try store.write(existing)

    // The next Sofia day's brief: yesterday's athlete pick must NOT carry over.
    let brief = makeBrief(date: sofiaInstant(2026, 7, 24))
    try store.mergeDailyBrief(brief, generatedAt: sofiaInstant(2026, 7, 24, 7, 0))

    let merged = try #require(store.read())
    #expect(merged.daily?.selectedSession == nil)
    #expect(merged.daily?.date == brief.date)
    // Sibling sections still preserved verbatim (their own staleness is their phases' concern).
    #expect(merged.weekly == existing.weekly)
    #expect(merged.checkIn == existing.checkIn)
  }

  @Test func test_mergeDailyBrief_noExistingFile_createsDailyOnlySnapshot() throws {
    let store = makeStore()
    let brief = makeBrief(date: sofiaInstant(2026, 7, 24))
    let generatedAt = sofiaInstant(2026, 7, 24, 7, 0)

    try store.mergeDailyBrief(brief, generatedAt: generatedAt)

    let merged = try #require(store.read())
    #expect(merged.generatedAt == generatedAt)
    #expect(merged.daily?.date == brief.date)
    #expect(merged.daily?.selectedSession == nil)
    #expect(merged.weekly == nil)
    #expect(merged.checkIn == nil)
  }

  // MARK: - Weekly merge (Phase 21.4)

  @Test func test_mergeWeeklyPlan_replacesWeeklyPreservesDailyAndCheckIn() throws {
    let store = makeStore()
    let existing = makeExisting(
      dailyDate: sofiaInstant(2026, 7, 24), selectedSession: alternativeSession
    ) // carries weekly "2026-W30" + a checkIn
    try store.write(existing)

    let plan = makeWeeklyPlan(isoWeek: "2026-W31", weekStart: sofiaInstant(2026, 7, 27))
    let generatedAt = sofiaInstant(2026, 7, 27, 8, 0)
    try store.mergeWeeklyPlan(plan, generatedAt: generatedAt)

    let merged = try #require(store.read())
    #expect(merged.generatedAt == generatedAt)
    #expect(merged.schemaVersion == WidgetSnapshot.currentSchemaVersion)
    // Weekly fields replaced by the fresh plan…
    #expect(merged.weekly?.isoWeek == "2026-W31")
    #expect(merged.weekly?.budgets == plan.budgets)
    #expect(merged.weekly?.targets == plan.targets)
    #expect(merged.weekly?.coreSessions == plan.core)
    // …the sibling sections are untouched (incl. the daily's selection).
    #expect(merged.daily == existing.daily)
    #expect(merged.checkIn == existing.checkIn)
  }

  /// The widget is core-only (epic 21.4: extras excluded) — the merge must never carry `extras`.
  @Test func test_mergeWeeklyPlan_excludesExtras() throws {
    let store = makeStore()
    let plan = makeWeeklyPlan(isoWeek: "2026-W30", weekStart: sofiaInstant(2026, 7, 20))

    try store.mergeWeeklyPlan(plan, generatedAt: sofiaInstant(2026, 7, 20, 8, 0))

    let merged = try #require(store.read())
    #expect(!plan.extras.isEmpty, "fixture must exercise the exclusion")
    #expect(merged.weekly?.coreSessions == plan.core)
    #expect(merged.weekly?.coreSessions.allSatisfy { $0.tier == .core } == true)
  }

  @Test func test_mergeWeeklyPlan_noExistingFile_createsWeeklyOnlySnapshot() throws {
    let store = makeStore()
    let plan = makeWeeklyPlan(isoWeek: "2026-W30", weekStart: sofiaInstant(2026, 7, 20))
    let generatedAt = sofiaInstant(2026, 7, 20, 8, 0)

    try store.mergeWeeklyPlan(plan, generatedAt: generatedAt)

    let merged = try #require(store.read())
    #expect(merged.generatedAt == generatedAt)
    #expect(merged.weekly?.isoWeek == plan.isoWeek)
    #expect(merged.daily == nil)
    #expect(merged.checkIn == nil)
  }
}
