import CoachCore
import DomainModels
import Foundation
import Testing
import WidgetSnapshotClient

/// Schema + Sofia staleness/timeline coverage for the `WidgetSnapshotClient` interface (Phase 21.1
/// TASK-001): the frozen wire shape 21.2–21.5 build on, and the shared date math every widget's
/// timeline provider reuses.
@Suite("WidgetSnapshot schema + timeline helpers")
struct WidgetSnapshotSchemaTests {
  // MARK: - Fixtures

  /// Build a fixed instant from Europe/Sofia wall-clock components — deterministic regardless of the
  /// host machine's locale/zone.
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

  private func makeDaily(
    date: Date,
    selectedSession: SessionBlock? = nil
  ) -> WidgetDailySnapshot {
    WidgetDailySnapshot(
      date: date,
      readiness: Readiness(score: 82, band: .green),
      safetyGate: SafetyGate(triggered: false),
      plannedSession: SessionBlock(
        card: .easyRun, intensity: .easy, zoneTarget: .z2, durationMinLow: 40, durationMinHigh: 50
      ),
      selectedSession: selectedSession,
      macroFocus: MacroFocus(
        dayType: .moderate, caloriesKcal: 2400, proteinG: 150, carbsG: 280,
        fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.0
      ),
      intakeYesterday: IntakeSummary(
        date: date.addingTimeInterval(-86_400),
        caloriesKcal: 2200,
        vsTarget: IntakeVsTarget(caloriesPct: 0.92, proteinHit: true)
      )
    )
  }

  private func makeWeekly(isoWeek: String) -> WidgetWeeklySnapshot {
    WidgetWeeklySnapshot(
      isoWeek: isoWeek,
      budgets: WeeklyBudgets(hardDays: 2, strengthSessions: 3, longRunKm: 14, deload: false),
      targets: WeeklyTargets(totalRunKm: 30, easyRunRatio: 0.8, strengthSessions: 3, hardDays: 2, cadenceSpm: 170),
      coreSessions: [
        PlannedSession(card: .longRun, tier: .core, intensity: .easy, isHardDay: false, suggestedDay: .sat),
      ]
    )
  }

  // MARK: - Codable round-trips

  @Test func test_roundTrip_allSectionsPopulated() throws {
    let date = sofiaInstant(2026, 7, 24)
    let snapshot = WidgetSnapshot(
      generatedAt: sofiaInstant(2026, 7, 24, 7, 30),
      daily: makeDaily(date: date),
      weekly: makeWeekly(isoWeek: "2026-W30"),
      checkIn: WidgetCheckInState(date: date, logged: true, source: .app)
    )

    let data = try WidgetSnapshotCoding.makeEncoder().encode(snapshot)
    let decoded = try WidgetSnapshotCoding.makeDecoder().decode(WidgetSnapshot.self, from: data)

    #expect(decoded == snapshot)
  }

  @Test func test_roundTrip_dailyOnly_optionalSectionsStayNil() throws {
    let snapshot = WidgetSnapshot(
      generatedAt: sofiaInstant(2026, 7, 24, 7, 30),
      daily: makeDaily(date: sofiaInstant(2026, 7, 24))
    )

    let data = try WidgetSnapshotCoding.makeEncoder().encode(snapshot)
    let decoded = try WidgetSnapshotCoding.makeDecoder().decode(WidgetSnapshot.self, from: data)

    #expect(decoded == snapshot)
    #expect(decoded.weekly == nil)
    #expect(decoded.checkIn == nil)
  }

  @Test func test_roundTrip_weeklyOnly_optionalSectionsStayNil() throws {
    let snapshot = WidgetSnapshot(
      generatedAt: sofiaInstant(2026, 7, 24, 7, 30),
      weekly: makeWeekly(isoWeek: "2026-W30")
    )

    let data = try WidgetSnapshotCoding.makeEncoder().encode(snapshot)
    let decoded = try WidgetSnapshotCoding.makeDecoder().decode(WidgetSnapshot.self, from: data)

    #expect(decoded == snapshot)
    #expect(decoded.daily == nil)
    #expect(decoded.checkIn == nil)
  }

  @Test func test_schemaVersion_defaultsToCurrent() {
    let snapshot = WidgetSnapshot(generatedAt: sofiaInstant(2026, 7, 24))
    #expect(snapshot.schemaVersion == WidgetSnapshot.currentSchemaVersion)
    #expect(WidgetSnapshot.currentSchemaVersion == 1)
  }

  /// The FROZEN daily-only wire shape (schemaVersion 1, ISO-8601 dates). Later phases decode files
  /// written by earlier builds — this literal is the compatibility contract.
  @Test func test_pinnedDailyOnlyJSON_decodes() throws {
    let json = """
    {
      "schemaVersion": 1,
      "generatedAt": "2026-07-24T04:30:00Z",
      "daily": {
        "date": "2026-07-23T21:00:00Z",
        "readiness": { "score": 82, "band": "green", "penalties": [] },
        "safetyGate": { "triggered": false, "reasons": [] },
        "plannedSession": {
          "card": "easy_run",
          "intensity": "easy",
          "zoneTarget": "z2",
          "durationMinLow": 40,
          "durationMinHigh": 50,
          "flags": []
        },
        "macroFocus": {
          "dayType": "moderate",
          "caloriesKcal": 2400,
          "proteinG": 150,
          "carbsG": 280,
          "fatGLow": 60,
          "fatGHigh": 80,
          "hydrationLLow": 2.5,
          "hydrationLHigh": 3.0
        }
      }
    }
    """
    let decoded = try WidgetSnapshotCoding.makeDecoder().decode(
      WidgetSnapshot.self, from: Data(json.utf8)
    )

    #expect(decoded.schemaVersion == 1)
    #expect(decoded.daily?.readiness.score == 82)
    #expect(decoded.daily?.plannedSession.card == .easyRun)
    #expect(decoded.daily?.selectedSession == nil)
    #expect(decoded.daily?.intakeYesterday == nil)
    #expect(decoded.weekly == nil)
    #expect(decoded.checkIn == nil)
  }

  /// The FROZEN weekly wire shape (Phase 21.4, still schemaVersion 1 — the section was carried in
  /// the v1 schema from day one). A widget build must keep decoding files the app wrote earlier.
  @Test func test_pinnedWeeklySectionJSON_decodes() throws {
    let json = """
    {
      "schemaVersion": 1,
      "generatedAt": "2026-07-24T04:30:00Z",
      "weekly": {
        "isoWeek": "2026-W30",
        "budgets": { "hardDays": 2, "strengthSessions": 3, "longRunKm": 14, "deload": false },
        "targets": {
          "totalRunKm": 30,
          "easyRunRatio": 0.8,
          "strengthSessions": 3,
          "hardDays": 2,
          "cadenceSpm": 170
        },
        "coreSessions": [
          {
            "card": "long_run",
            "tier": "core",
            "intensity": "easy",
            "isHardDay": false,
            "suggestedDay": "sat",
            "flags": []
          }
        ]
      }
    }
    """
    let decoded = try WidgetSnapshotCoding.makeDecoder().decode(
      WidgetSnapshot.self, from: Data(json.utf8)
    )

    #expect(decoded.weekly?.isoWeek == "2026-W30")
    #expect(decoded.weekly?.budgets.deload == false)
    #expect(decoded.weekly?.budgets.longRunKm == 14)
    #expect(decoded.weekly?.targets.cadenceSpm == 170)
    #expect(decoded.weekly?.coreSessions.count == 1)
    #expect(decoded.weekly?.coreSessions.first?.card == .longRun)
    #expect(decoded.weekly?.coreSessions.first?.suggestedDay == .sat)
    #expect(decoded.daily == nil)
    #expect(decoded.checkIn == nil)
  }

  // MARK: - nextSofiaMidnight

  @Test func test_nextSofiaMidnight_midDay_returnsNextDayStart() {
    let now = sofiaInstant(2026, 1, 16, 0, 30)
    let next = WidgetTimeline.nextSofiaMidnight(after: now)
    #expect(next == sofiaInstant(2026, 1, 17))
  }

  @Test func test_nextSofiaMidnight_exactlyAtMidnight_returnsFollowingMidnight() {
    let midnight = sofiaInstant(2026, 1, 16)
    let next = WidgetTimeline.nextSofiaMidnight(after: midnight)
    #expect(next == sofiaInstant(2026, 1, 17))
  }

  @Test func test_nextSofiaMidnight_acrossMonthBoundary() {
    let now = sofiaInstant(2026, 1, 31, 12, 0)
    let next = WidgetTimeline.nextSofiaMidnight(after: now)
    #expect(next == sofiaInstant(2026, 2, 1))
  }

  // MARK: - Daily isCurrent

  @Test func test_dailyIsCurrent_sameSofiaDay_true() {
    let daily = makeDaily(date: sofiaInstant(2026, 1, 16))
    #expect(daily.isCurrent(at: sofiaInstant(2026, 1, 16, 23, 45)))
  }

  @Test func test_dailyIsCurrent_justPastSofiaMidnight_false() {
    let daily = makeDaily(date: sofiaInstant(2026, 1, 16))
    #expect(!daily.isCurrent(at: sofiaInstant(2026, 1, 17, 0, 10)))
  }

  /// Sofia is UTC+2 in winter: 00:30 Sofia on Jan 16 is still 22:30 UTC on Jan 15. The helper must
  /// judge the SOFIA day, not the UTC one.
  @Test func test_dailyIsCurrent_utcDayDiffersFromSofiaDay() {
    // 2026-01-16 00:30 Sofia == 2026-01-15 22:30 UTC.
    let now = Date(timeIntervalSince1970: 1_768_516_200)
    var utcCalendar = Calendar(identifier: .iso8601)
    // Force-unwrap: "UTC" is a fixed valid identifier.
    utcCalendar.timeZone = TimeZone(identifier: "UTC")!
    #expect(utcCalendar.component(.day, from: now) == 15)

    let daily = makeDaily(date: sofiaInstant(2026, 1, 16))
    #expect(daily.isCurrent(at: now))

    let yesterdaysBrief = makeDaily(date: sofiaInstant(2026, 1, 15))
    #expect(!yesterdaysBrief.isCurrent(at: now))
  }

  // MARK: - Weekly isCurrent

  @Test func test_weeklyIsCurrent_sameISOWeek_true() {
    let weekly = makeWeekly(isoWeek: "2026-W03")
    // 2026-01-16 is a Friday in ISO week 3 of 2026.
    #expect(weekly.isCurrent(at: sofiaInstant(2026, 1, 16, 12, 0)))
  }

  @Test func test_weeklyIsCurrent_afterRollover_false() {
    let weekly = makeWeekly(isoWeek: "2026-W03")
    // Monday of ISO week 4.
    #expect(!weekly.isCurrent(at: sofiaInstant(2026, 1, 19, 0, 10)))
  }

  /// 2025-12-29 (a Monday) belongs to ISO week 2026-W01 — the year-boundary case the `"%04d-W%02d"`
  /// formatter must get right (ISO year ≠ calendar year).
  @Test func test_weeklyIsCurrent_isoYearBoundary() {
    let weekly = makeWeekly(isoWeek: "2026-W01")
    #expect(weekly.isCurrent(at: sofiaInstant(2025, 12, 29, 12, 0)))
    #expect(!weekly.isCurrent(at: sofiaInstant(2025, 12, 28, 12, 0)))
  }

  // MARK: - Dependency plumbing

  @Test func test_testValue_isNoOpAndReadsNil() async {
    let client = WidgetSnapshotClient.testValue
    await client.updateDailyBrief(
      DailyBrief(
        date: sofiaInstant(2026, 7, 24),
        readiness: Readiness(score: 50, band: .amber),
        safetyGate: SafetyGate(triggered: false),
        session: SessionBlock(card: .rest, intensity: .recovery, durationMinLow: 0, durationMinHigh: 0),
        skipOk: true,
        macroFocus: MacroFocus(
          dayType: .rest, caloriesKcal: 2000, proteinG: 140, carbsG: 180,
          fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.0, hydrationLHigh: 2.5
        ),
        generatedAt: sofiaInstant(2026, 7, 24, 7, 0),
        cached: false
      )
    )
    let snapshot = await client.read()
    #expect(snapshot == nil)
  }
}
