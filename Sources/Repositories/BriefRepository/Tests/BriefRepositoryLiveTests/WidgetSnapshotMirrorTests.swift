import APIClient
import BriefRepository
import CoachCore
import CoachTestSupport
import Database
import Dependencies
import DomainModels
import Foundation
import SampleData
import Testing
import WidgetSnapshotClient
import WireModels

import BriefRepositoryLive

/// The Phase 21.1 widget-snapshot mirror hook: `dailyBriefPolicy` fires `updateDailyBrief` exactly
/// once per daily CACHE WRITE (first generate and refresh) — never on a pure cache hit (the snapshot
/// was mirrored when that row was written) and never on an API error. Un-overridden suites stay
/// green via the interface's no-op `testValue`.
struct WidgetSnapshotMirrorTests {
  private func greenFixture() throws -> (dto: WireModels.DailyBrief, domain: DomainModels.DailyBrief) {
    try SampleData.dailyBrief(.dailyBriefGreen)
  }

  /// `runWithSofia` + a recording `\.widgetSnapshot` override capturing every mirrored brief.
  private func runRecordingMirror<T>(
    now: Date,
    stub: BriefAPIStub,
    database: DatabaseClient,
    into recorder: CallRecorder<DomainModels.DailyBrief>,
    _ work: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(now)
      $0.apiClient = stub.makeClient()
      $0.database = database
      $0.widgetSnapshot = WidgetSnapshotClient(
        updateDailyBrief: { recorder.record($0) },
        read: { nil }
      )
    } operation: {
      try await work()
    }
  }

  @Test func test_generatePath_mirrorsServedBriefOnce() async throws {
    let (dto, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = BriefAPIStub(dailyResult: .success(dto))
    let recorder = CallRecorder<DomainModels.DailyBrief>()

    let result = try await runRecordingMirror(now: domain.date, stub: stub, database: db, into: recorder) {
      try await BriefRepository.live.dailyBrief(false)
    }

    #expect(result == domain)
    #expect(recorder.count == 1, "a cache-miss generate writes the row → mirrors once")
    #expect(recorder.lastArgument == domain, "the mirror receives the served brief")
  }

  @Test func test_refresh_mirrorsOnce() async throws {
    let (dto, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    try await TestDatabase.seedDaily(db, domain) // same-day cached row — refresh overwrites it
    let stub = BriefAPIStub(dailyResult: .success(dto))
    let recorder = CallRecorder<DomainModels.DailyBrief>()

    _ = try await runRecordingMirror(now: domain.date, stub: stub, database: db, into: recorder) {
      try await BriefRepository.live.dailyBrief(true)
    }

    #expect(recorder.count == 1, "a refresh overwrite is a cache write → mirrors once")
  }

  @Test func test_pureCacheHit_doesNotMirror() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedDaily(db, domain)
    let stub = BriefAPIStub()
    let recorder = CallRecorder<DomainModels.DailyBrief>()

    let result = try await runRecordingMirror(now: domain.date, stub: stub, database: db, into: recorder) {
      try await BriefRepository.live.dailyBrief(false)
    }

    #expect(result == domain)
    #expect(recorder.count == 0, "a zero-write cache hit must not re-mirror (DECISIONS D6)")
  }

  @Test func test_apiErrorPath_doesNotMirror() async throws {
    let (_, domain) = try greenFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = BriefAPIStub(dailyResult: .failure(.transport("offline")))
    let recorder = CallRecorder<DomainModels.DailyBrief>()

    await expectBriefError(.transientGenerationFailed) {
      try await runRecordingMirror(now: domain.date, stub: stub, database: db, into: recorder) {
        try await BriefRepository.live.dailyBrief(false)
      }
    }
    #expect(recorder.count == 0, "no cache write on the error path → no mirror")
  }
}
