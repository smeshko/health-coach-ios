import CoachCore
import DomainModels
import Foundation
import Testing
import WidgetSnapshotClient
import WidgetSnapshotClientLive

/// The Phase 21.5 check-in section merge: same-day/newer-day replacement, the prior-day guard (a
/// late drain of yesterday's pending entry after midnight must never stomp today's already-logged
/// state), and the no-schema-surgery sibling-section guarantee. Its own suite — folding these into
/// `WidgetSnapshotStoreTests` would push that type past the type-body-length limit.
@Suite("WidgetSnapshotStore check-in merge")
struct WidgetSnapshotStoreCheckInMergeTests {
  // MARK: - Fixtures (mirrors of the WidgetSnapshotStoreTests fixtures this suite needs)

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

  // MARK: - Check-in merge (Phase 21.5)

  @Test func test_mergeCheckIn_replacesCheckInPreservesSiblingSections() throws {
    let store = makeStore()
    let day = sofiaInstant(2026, 7, 24)
    let existing = makeExisting(dailyDate: day, selectedSession: alternativeSession)
    try store.write(existing)

    let incoming = WidgetCheckInState(date: day, logged: true, source: .widget)
    let generatedAt = sofiaInstant(2026, 7, 24, 8, 15)
    try store.mergeCheckIn(incoming, generatedAt: generatedAt)

    let merged = try #require(store.read())
    #expect(merged.generatedAt == generatedAt)
    #expect(merged.checkIn == incoming)
    // Sibling sections untouched — the no-schema-surgery guarantee.
    #expect(merged.daily == existing.daily)
    #expect(merged.weekly == existing.weekly)
  }

  @Test func test_mergeCheckIn_noExistingFile_createsCheckInOnlySnapshot() throws {
    let store = makeStore()
    let incoming = WidgetCheckInState(date: sofiaInstant(2026, 7, 24), logged: true, source: .widget)

    try store.mergeCheckIn(incoming, generatedAt: sofiaInstant(2026, 7, 24, 8, 15))

    let merged = try #require(store.read())
    #expect(merged.checkIn == incoming)
    #expect(merged.daily == nil)
    #expect(merged.weekly == nil)
  }

  /// A PRIOR-day write (e.g. yesterday's pending entry draining after midnight) must never stomp a
  /// later day's state — today's widget would wrongly flip back to unlogged.
  @Test func test_mergeCheckIn_priorDayIncoming_keepsLaterDayState() throws {
    let store = makeStore()
    let today = WidgetCheckInState(date: sofiaInstant(2026, 7, 24), logged: true, source: .app)
    try store.write(WidgetSnapshot(generatedAt: sofiaInstant(2026, 7, 24, 7, 0), checkIn: today))

    let yesterday = WidgetCheckInState(date: sofiaInstant(2026, 7, 23), logged: true, source: .widget)
    try store.mergeCheckIn(yesterday, generatedAt: sofiaInstant(2026, 7, 24, 9, 0))

    #expect(store.read()?.checkIn == today)
  }

  @Test func test_mergeCheckIn_newDayIncoming_replacesPriorDayState() throws {
    let store = makeStore()
    let yesterday = WidgetCheckInState(date: sofiaInstant(2026, 7, 23), logged: true, source: .app)
    try store.write(WidgetSnapshot(generatedAt: sofiaInstant(2026, 7, 23, 7, 0), checkIn: yesterday))

    let today = WidgetCheckInState(date: sofiaInstant(2026, 7, 24), logged: true, source: .widget)
    try store.mergeCheckIn(today, generatedAt: sofiaInstant(2026, 7, 24, 9, 0))

    #expect(store.read()?.checkIn == today)
  }
}
