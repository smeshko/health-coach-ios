import APIClient
import BriefRepository
import CoachTestSupport
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import SampleData
import Testing
import WireModels

@testable import BriefRepositoryLive
@testable import Database

/// Pins DECISIONS D3's ACCEPTED post-upgrade behavior change. After `v3_clearDomainBodyCaches` empties
/// the composite caches, the first launch behaves like a fresh install: a pre-v3 database that HELD a
/// cached daily + weekly brief — which would have classified a 500 `internal_error` as `.serverError`
/// (prior-row path, `APIErrorMapping`) — now classifies it as `.insufficientData` (first-ever path),
/// once, until a brief re-caches. This is the deliberate one-time degradation, not a bug.
struct PostUpgradeCacheClearTests {
  /// A `DatabaseClient` over a queue migrated only to v2 (pre-v3), so rows seeded into it survive until
  /// the caller runs the full migrator (which applies v3).
  private func makePreV3Database() throws -> (DatabaseClient, DatabaseQueue) {
    let queue = try DatabaseQueue()
    try DatabaseClient.migrator.migrate(queue, upTo: "v2_addLastStrengthTestSyncedWeek")
    return (DatabaseClient(reader: { queue }, writer: { queue }), queue)
  }

  @Test func test_postUpgrade_clearedCache_500_classifiesAsInsufficientData() async throws {
    let (database, queue) = try makePreV3Database()
    let daily = try SampleData.dailyBrief(.dailyBriefGreen).domain
    let weekly = try SampleData.weeklyPlan(.weeklyPlanDeload).domain

    // Pre-v3: a cached daily (today) + weekly exist — the "has prior row" path.
    try await TestDatabase.seedDaily(database, daily)
    try await TestDatabase.seedWeekly(database, weekly)

    // Apply v3 → both composite caches are cleared.
    try DatabaseClient.migrator.migrate(queue)
    let dailyCount = try await TestDatabase.dailyCount(database)
    let weeklyCount = try await TestDatabase.weeklyCount(database)
    #expect(dailyCount == 0)
    #expect(weeklyCount == 0)

    // The sync watermark is a flat table retained by v3, so the policy reaches the 500 classifier
    // rather than short-circuiting at the sync gate.
    try await TestDatabase.seedWatermark(database)

    let stub = BriefAPIStub(
      dailyResult: .failure(envelopeError(.internalError, 500)),
      weeklyResult: .failure(envelopeError(.internalError, 500))
    )

    // Both routes take the first-ever path → `.insufficientData`, NOT `.serverError` (the prior row
    // that keyed `.serverError` was cleared by v3). This IS D3's accepted post-upgrade regression.
    await expectBriefError(.insufficientData) {
      try await runWithSofia(now: daily.date, stub: stub, database: database) {
        try await BriefRepository.live.dailyBrief(false)
      }
    }
    await expectBriefError(.insufficientData) {
      try await runWithSofia(now: daily.date, stub: stub, database: database) {
        try await BriefRepository.live.weeklyBrief(nil, false)
      }
    }
  }
}
