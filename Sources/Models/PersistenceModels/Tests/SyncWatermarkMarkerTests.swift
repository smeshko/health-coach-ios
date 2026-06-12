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

}
