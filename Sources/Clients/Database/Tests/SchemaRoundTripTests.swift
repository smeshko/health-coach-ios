import Database
import DatabaseLive
import Foundation
import GRDB
import PersistenceModels
import XCTest

/// Round-trips **every** record type through a migrated in-memory queue, so a future schema/column
/// mismatch (a renamed column, a wrong NOT NULL) can't regress unnoticed (round-1 review gap A).
final class SchemaRoundTripTests: XCTestCase {
  private func roundTrip<R: FetchableRecord & PersistableRecord & Equatable & Sendable>(
    _ record: R, in database: DatabaseClient
  ) async throws -> [R] {
    try await database.write { db in try record.save(db) }
    return try await database.read { db in try R.fetchAll(db) }
  }

  func test_everyRecordType_roundTrips() async throws {
    let day = Date(timeIntervalSince1970: 1_780_000_000)
    let database = try DatabaseClient.makeInMemory()
    let body = Data("payload".utf8)

    let dailyBrief = DailyBriefRecord(
      date: day, cached: true, generatedAt: day, constitutionVersion: "v3", body: body
    )
    let weeklyPlan = WeeklyPlanRecord(
      isoWeek: "2026-W24", weekStart: day, constantsRecomputed: false, generatedAt: day,
      cached: false, body: body
    )
    let checkIn = CheckInRecord(date: day, giSymptoms: true, kneePain: 4, illness: false)
    let strengthTest = StrengthTestRecord(date: day, maxPushups: 42, maxPullups: 14)
    let watermark = SyncWatermarkRecord(anchor: "anchor", serverTime: day)
    let profile = ProfileRecord(constitutionVersion: "v3", body: body)

    let dailyBriefBack = try await roundTrip(dailyBrief, in: database)
    XCTAssertEqual(dailyBriefBack, [dailyBrief])
    let weeklyPlanBack = try await roundTrip(weeklyPlan, in: database)
    XCTAssertEqual(weeklyPlanBack, [weeklyPlan])
    let checkInBack = try await roundTrip(checkIn, in: database)
    XCTAssertEqual(checkInBack, [checkIn])
    let strengthTestBack = try await roundTrip(strengthTest, in: database)
    XCTAssertEqual(strengthTestBack, [strengthTest])
    let watermarkBack = try await roundTrip(watermark, in: database)
    XCTAssertEqual(watermarkBack, [watermark])
    let profileBack = try await roundTrip(profile, in: database)
    XCTAssertEqual(profileBack, [profile])
  }
}
