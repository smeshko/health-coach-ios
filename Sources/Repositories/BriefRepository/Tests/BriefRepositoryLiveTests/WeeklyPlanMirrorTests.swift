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

/// The Phase 21.4 weekly widget-snapshot mirror hook: `weeklyPlanPolicy` fires `updateWeeklyPlan`
/// exactly once per weekly CACHE WRITE (first generate and refresh) — never on a pure cache hit and
/// never on an API error (the daily hook's `WidgetSnapshotMirrorTests` convention).
struct WeeklyPlanMirrorTests {
  private func deloadFixture() throws -> (dto: WireModels.WeeklyPlan, domain: DomainModels.WeeklyPlan) {
    try SampleData.weeklyPlan(.weeklyPlanDeload)
  }

  /// `runWithSofia` + a recording `\.widgetSnapshot` override capturing every mirrored plan.
  private func runRecordingMirror<T>(
    now: Date,
    stub: BriefAPIStub,
    database: DatabaseClient,
    into recorder: CallRecorder<DomainModels.WeeklyPlan>,
    _ work: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withDependencies {
      $0.useEuropeSofia()
      $0.date = .constant(now)
      $0.apiClient = stub.makeClient()
      $0.database = database
      $0.widgetSnapshot = WidgetSnapshotClient(
        updateDailyBrief: { _ in },
        updateWeeklyPlan: { recorder.record($0) },
        read: { nil }
      )
    } operation: {
      try await work()
    }
  }

  @Test func test_generatePath_mirrorsServedPlanOnce() async throws {
    let (dto, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = BriefAPIStub(weeklyResult: .success(dto))
    let recorder = CallRecorder<DomainModels.WeeklyPlan>()

    let result = try await runRecordingMirror(
      now: domain.weekStart, stub: stub, database: db, into: recorder
    ) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }

    #expect(result == domain)
    #expect(recorder.count == 1, "a cache-miss generate writes the row → mirrors once")
    #expect(recorder.lastArgument == domain, "the mirror receives the served plan")
  }

  @Test func test_refresh_mirrorsOnce() async throws {
    let (dto, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    try await TestDatabase.seedWeekly(db, domain) // same-week cached row — refresh overwrites it
    let stub = BriefAPIStub(weeklyResult: .success(dto))
    let recorder = CallRecorder<DomainModels.WeeklyPlan>()

    _ = try await runRecordingMirror(
      now: domain.weekStart, stub: stub, database: db, into: recorder
    ) {
      try await BriefRepository.live.weeklyBrief(nil, true)
    }

    #expect(recorder.count == 1, "a refresh overwrite is a cache write → mirrors once")
  }

  @Test func test_pureCacheHit_doesNotMirror() async throws {
    let (_, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWeekly(db, domain)
    let stub = BriefAPIStub()
    let recorder = CallRecorder<DomainModels.WeeklyPlan>()

    _ = try await runRecordingMirror(
      now: domain.weekStart, stub: stub, database: db, into: recorder
    ) {
      try await BriefRepository.live.weeklyBrief(nil, false)
    }

    #expect(recorder.count == 0, "a zero-write cache hit must not re-mirror")
  }

  @Test func test_apiErrorPath_doesNotMirror() async throws {
    let (_, domain) = try deloadFixture()
    let db = try TestDatabase.makeInMemory()
    try await TestDatabase.seedWatermark(db)
    let stub = BriefAPIStub(weeklyResult: .failure(.transport("offline")))
    let recorder = CallRecorder<DomainModels.WeeklyPlan>()

    await expectBriefError(.transientGenerationFailed) {
      try await runRecordingMirror(
        now: domain.weekStart, stub: stub, database: db, into: recorder
      ) {
        try await BriefRepository.live.weeklyBrief(nil, false)
      }
    }
    #expect(recorder.count == 0, "no cache write on the error path → no mirror")
  }
}
