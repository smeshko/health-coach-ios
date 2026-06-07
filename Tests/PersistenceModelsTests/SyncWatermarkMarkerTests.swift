import CoachCore
import Foundation
import PersistenceModels
import XCTest

final class SyncWatermarkMarkerTests: XCTestCase {
  func test_syncWatermark_roundTrips_withStrengthWeekMarker() {
    let week = ISOWeek(year: 2026, week: 24)
    let domain = SyncWatermark(
      anchor: "anchor-token",
      serverTime: Date(timeIntervalSince1970: 1000),
      lastStrengthTestSyncedWeek: week
    )
    let record = SyncWatermarkRecord(domain: domain)
    XCTAssertEqual(record.lastStrengthTestSyncedWeek, week)
    XCTAssertEqual(record.toDomain(), domain)
  }

  func test_syncWatermark_roundTrips_withNilMarker() {
    let domain = SyncWatermark(anchor: nil, serverTime: Date(timeIntervalSince1970: 0))
    let record = SyncWatermarkRecord(domain: domain)
    XCTAssertNil(record.lastStrengthTestSyncedWeek)
    XCTAssertEqual(record.toDomain(), domain)
  }

  func test_isoWeekMarker_distinguishesYears() {
    // A bare weekOfYear would collide; the year-qualified marker must not.
    XCTAssertNotEqual(ISOWeek(year: 2026, week: 1), ISOWeek(year: 2027, week: 1))
    XCTAssertEqual(ISOWeek(year: 2026, week: 1), ISOWeek(year: 2026, week: 1))
  }
}
