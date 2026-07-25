import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import Testing
import WidgetSnapshotClient

@testable import LocalRepositories

/// The Phase 21.5 widget seams of `CheckInRepository.live`: the `save` → snapshot mirror, and the
/// inbox drain's idempotency + in-app-wins precedence. The `\.widgetSnapshot` client is overridden
/// with an in-memory recording fake — never the real App Group container.
struct CheckInWidgetDrainTests {
  /// A fixed Europe/Sofia instant (~09:00 on 2026-06-06), same anchor as CheckInRepositoryLiveTests.
  private static let now = Date(timeIntervalSince1970: 1_780_725_600)

  /// A tiny thread-safe recorder (the CallRecorder shape, local to this suite — the test target
  /// doesn't link CoachTestSupport).
  private final class Recorder<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [Value] = []

    var values: [Value] { lock.withLock { _values } }
    func record(_ value: Value) { lock.withLock { _values.append(value) } }
  }

  /// An in-memory stand-in for the App Group inbox: `pendingCheckIns` serves `pending` until
  /// `clearPendingCheckIns` empties it (mirroring the file store's drain lifecycle).
  private final class InboxFake: @unchecked Sendable {
    private let lock = NSLock()
    private var _pending: [DomainModels.CheckIn]
    private var _clearCount = 0

    init(pending: [DomainModels.CheckIn]) { _pending = pending }

    var pending: [DomainModels.CheckIn] { lock.withLock { _pending } }
    var clearCount: Int { lock.withLock { _clearCount } }
    func clear() {
      lock.withLock {
        _pending = []
        _clearCount += 1
      }
    }
  }

  private func run<T>(
    database: DatabaseClient,
    inbox: InboxFake,
    mirror: Recorder<WidgetCheckInState> = Recorder(),
    now: Date = CheckInWidgetDrainTests.now,
    _ work: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(now)
      $0.database = database
      $0.widgetSnapshot = WidgetSnapshotClient(
        updateDailyBrief: { _ in },
        read: { nil },
        updateCheckIn: { mirror.record($0) },
        pendingCheckIns: { inbox.pending },
        clearPendingCheckIns: { inbox.clear() }
      )
    } operation: {
      try await work()
    }
  }

  private static func allClear(date: Date) -> DomainModels.CheckIn {
    DomainModels.CheckIn(date: date, giSymptoms: false, kneePain: 0, illness: false)
  }

  // MARK: - Save mirrors the logged state

  @Test func test_save_mirrorsLoggedStateWithAppSource() async throws {
    let db = try DatabaseClient.makeInMemory()
    let mirror = Recorder<WidgetCheckInState>()
    let inbox = InboxFake(pending: [])

    try await run(database: db, inbox: inbox, mirror: mirror) {
      try await CheckInRepository.live.save(
        DomainModels.CheckIn(date: Self.now, giSymptoms: true, kneePain: 3, illness: false)
      )
    }

    let state = try #require(mirror.values.last)
    #expect(mirror.values.count == 1)
    #expect(state.logged)
    #expect(state.source == .app)
    // The mirrored day is the repo's normalized Sofia day key.
    #expect(state.date == Calendar.europeSofia.startOfDay(for: Self.now))
  }

  // MARK: - Drain

  @Test func test_drain_persistsPendingAllClearWithDefaults() async throws {
    let db = try DatabaseClient.makeInMemory()
    let inbox = InboxFake(pending: [Self.allClear(date: Self.now)])

    try await run(database: db, inbox: inbox) {
      try await CheckInRepository.live.drainWidgetInbox()
    }

    let current = try await run(database: db, inbox: inbox) {
      try await CheckInRepository.live.current(Self.now)
    }
    #expect(current?.giSymptoms == false)
    #expect(current?.kneePain == 0)
    #expect(current?.illness == false)
    #expect(inbox.clearCount == 1, "a completed drain must clear the inbox")
  }

  @Test func test_drainTwice_createsOneRecord() async throws {
    let db = try DatabaseClient.makeInMemory()
    let inbox = InboxFake(pending: [Self.allClear(date: Self.now)])

    try await run(database: db, inbox: inbox) {
      try await CheckInRepository.live.drainWidgetInbox()
      try await CheckInRepository.live.drainWidgetInbox()
    }

    let count = try await db.read { dbx in try CheckInRecord.fetchCount(dbx) }
    #expect(count == 1, "a re-drain must not duplicate (or even re-save) the record")
  }

  /// The idempotency guard must hold even when the inbox survives a drain (e.g. the clear failed):
  /// the already-persisted day is skipped by the existing-record check, not by the empty inbox.
  @Test func test_drain_withUnclearedInbox_staysIdempotent() async throws {
    let db = try DatabaseClient.makeInMemory()
    let sticky = Self.allClear(date: Self.now)

    // First drain persists; the second serves the SAME pending entry again (clear "failed").
    let inbox1 = InboxFake(pending: [sticky])
    try await run(database: db, inbox: inbox1) {
      try await CheckInRepository.live.drainWidgetInbox()
    }
    let inbox2 = InboxFake(pending: [sticky])
    try await run(database: db, inbox: inbox2) {
      try await CheckInRepository.live.drainWidgetInbox()
    }

    let count = try await db.read { dbx in try CheckInRecord.fetchCount(dbx) }
    #expect(count == 1)
  }

  @Test func test_drain_sameDay_inAppCheckInWins() async throws {
    let db = try DatabaseClient.makeInMemory()
    let inbox = InboxFake(pending: [Self.allClear(date: Self.now)])
    let inApp = DomainModels.CheckIn(date: Self.now, giSymptoms: true, kneePain: 7, illness: true)

    try await run(database: db, inbox: inbox) {
      try await CheckInRepository.live.save(inApp)
      try await CheckInRepository.live.drainWidgetInbox()
    }

    // The pending all-clear must never overwrite the same-day in-app record.
    let current = try await run(database: db, inbox: inbox) {
      try await CheckInRepository.live.current(Self.now)
    }
    #expect(current?.giSymptoms == true)
    #expect(current?.kneePain == 7)
    #expect(current?.illness == true)
    let count = try await db.read { dbx in try CheckInRecord.fetchCount(dbx) }
    #expect(count == 1)
    #expect(inbox.clearCount == 1, "the superseded entry still drains away")
  }

  @Test func test_drain_emptyInbox_isANoOp() async throws {
    let db = try DatabaseClient.makeInMemory()
    let inbox = InboxFake(pending: [])

    try await run(database: db, inbox: inbox) {
      try await CheckInRepository.live.drainWidgetInbox()
    }

    let count = try await db.read { dbx in try CheckInRecord.fetchCount(dbx) }
    #expect(count == 0)
    #expect(inbox.clearCount == 0, "an empty inbox is never touched")
  }

  /// A pending entry from a PREVIOUS Sofia day (the app wasn't opened until after midnight) still
  /// drains — under ITS day key, without colliding with today.
  @Test func test_drain_yesterdaysPending_persistsUnderItsOwnDay() async throws {
    let db = try DatabaseClient.makeInMemory()
    let yesterday = Self.now.addingTimeInterval(-86_400)
    let inbox = InboxFake(pending: [Self.allClear(date: yesterday)])

    try await run(database: db, inbox: inbox) {
      try await CheckInRepository.live.drainWidgetInbox()
    }

    let drained = try await run(database: db, inbox: inbox) {
      try await CheckInRepository.live.current(yesterday)
    }
    #expect(drained != nil)
    let today = try await run(database: db, inbox: inbox) {
      try await CheckInRepository.live.current(Self.now)
    }
    #expect(today == nil)
  }
}
