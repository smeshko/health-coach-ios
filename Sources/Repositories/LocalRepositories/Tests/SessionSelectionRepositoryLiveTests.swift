import CoachCore
import CoachTestSupport
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import Testing
import WidgetSnapshotClient

@testable import LocalRepositories

/// `SessionSelectionRepository.live` over an in-memory `Database` (mirrors `CheckInRepositoryTests`): a
/// round-trip save→current, same-day latest-wins upsert, missing→nil, and cross-Sofia-day isolation. The
/// in-memory DB runs the `v4_createSessionSelection` migration at open, so these also exercise the schema.
struct SessionSelectionRepositoryTests {
  /// A fixed Europe/Sofia instant (~09:00 on 2026-06-06). `static` so the `@Sendable` work closures capture
  /// it without capturing the (non-Sendable) test case.
  private static let now = Date(timeIntervalSince1970: 1_780_725_600)

  /// The recommended primary — an easy Z2 run with a bpm/cadence line.
  private static func easyRun() -> SessionBlock {
    SessionBlock(
      card: .easyRun, intensity: .easy, zoneTarget: .z2,
      durationMinLow: 35, durationMinHigh: 45, hrCapBpm: 146, cadenceSpm: 170, flags: [.lowImpact]
    )
  }

  /// A distinct alternative — a no-zone strength block.
  private static func strength() -> SessionBlock {
    SessionBlock(card: .strengthFull, intensity: .quality, durationMinLow: 30, durationMinHigh: 30)
  }

  private func run<T>(
    database: DatabaseClient,
    now: Date = SessionSelectionRepositoryTests.now,
    _ work: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(now)
      $0.database = database
    } operation: {
      try await work()
    }
  }

  @Test func test_save_thenCurrent_roundTripsBlock() async throws {
    let db = try DatabaseClient.makeInMemory()
    let block = Self.easyRun()

    try await run(database: db) { try await SessionSelectionRepository.live.save(block, Self.now) }
    let current = try await run(database: db) { try await SessionSelectionRepository.live.current(Self.now) }

    #expect(current == block, "the decoded block must equal the saved one (lossless by value)")
  }

  @Test func test_sameDay_resave_latestWins() async throws {
    let db = try DatabaseClient.makeInMemory()

    try await run(database: db) {
      try await SessionSelectionRepository.live.save(Self.easyRun(), Self.now)
      // +6h — still the same Europe/Sofia day; a second pick overwrites the first.
      try await SessionSelectionRepository.live.save(Self.strength(), Self.now.addingTimeInterval(6 * 3600))
    }

    let count = try await db.read { dbx in try SessionSelectionRecord.fetchCount(dbx) }
    #expect(count == 1, "two same-day saves must collide on one row")
    let current = try await run(database: db) { try await SessionSelectionRepository.live.current(Self.now) }
    #expect(current == Self.strength(), "the latest same-day save wins")
  }

  @Test func test_current_missing_returnsNil() async throws {
    let db = try DatabaseClient.makeInMemory()
    let current = try await run(database: db) { try await SessionSelectionRepository.live.current(Self.now) }
    #expect(current == nil)
  }

  /// A pick saved "today" is NOT returned by `current(yesterday)` — the Sofia-day key isolates days, so the
  /// next day starts with no stored pick (the carousel falls back to the primary).
  @Test func test_differentSofiaDay_returnsNil() async throws {
    let db = try DatabaseClient.makeInMemory()
    let yesterday = Self.now.addingTimeInterval(-24 * 3600)

    try await run(database: db) { try await SessionSelectionRepository.live.save(Self.easyRun(), Self.now) }
    let prior = try await run(database: db) {
      try await SessionSelectionRepository.live.current(yesterday)
    }
    #expect(prior == nil, "a different Sofia day has no stored pick")
  }

  /// The Phase 21.2 widget mirror hook: `save` fires `updateSelectedSession` exactly once per save,
  /// with the saved block and the normalized Sofia day (not the raw wall-clock instant). Suites
  /// without an override stay green via the interface's defaulted no-op.
  @Test func test_save_mirrorsSelectionWithNormalizedSofiaDay() async throws {
    let db = try DatabaseClient.makeInMemory()
    let recorder = CallRecorder<(DomainModels.SessionBlock, Date)>()
    let block = Self.easyRun()

    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(Self.now)
      $0.database = db
      $0.widgetSnapshot = WidgetSnapshotClient(
        updateDailyBrief: { _ in },
        updateSelectedSession: { recorder.record(($0, $1)) },
        read: { nil }
      )
    } operation: {
      try await SessionSelectionRepository.live.save(block, Self.now)
    }

    #expect(recorder.count == 1, "one save → one mirror")
    #expect(recorder.lastArgument?.0 == block, "the mirror receives the saved block")
    #expect(
      recorder.lastArgument?.1 == Calendar.europeSofia.startOfDay(for: Self.now),
      "the mirrored day is the normalized Sofia day the row was keyed on"
    )
  }
}
