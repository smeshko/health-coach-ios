import CoachCore
import Foundation
import PersistenceModels
import Testing

struct SyncWatermarkMarkerTests {
  @Test func test_syncWatermark_roundTrips_withStrengthWeekMarker() {
    let week = ISOWeek(year: 2026, week: 24)
    let domain = SyncWatermark(
      anchor: "anchor-token",
      serverTime: Date(timeIntervalSince1970: 1000),
      lastStrengthTestSyncedWeek: week
    )
    let record = SyncWatermarkRecord(domain: domain)
    #expect(record.lastStrengthTestSyncedWeek == week)
    #expect(record.toDomain() == domain)
  }

  @Test func test_syncWatermark_roundTrips_withNilMarker() {
    let domain = SyncWatermark(anchor: nil, serverTime: Date(timeIntervalSince1970: 0))
    let record = SyncWatermarkRecord(domain: domain)
    #expect(record.lastStrengthTestSyncedWeek == nil)
    #expect(record.toDomain() == domain)
  }

  @Test func test_isoWeekMarker_distinguishesYears() {
    // A bare weekOfYear would collide; the year-qualified marker must not.
    #expect(ISOWeek(year: 2026, week: 1) != ISOWeek(year: 2027, week: 1))
    #expect(ISOWeek(year: 2026, week: 1) == ISOWeek(year: 2026, week: 1))
  }
}
