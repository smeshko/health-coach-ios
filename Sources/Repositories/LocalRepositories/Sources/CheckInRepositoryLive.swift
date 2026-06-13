import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels

extension CheckInRepository: DependencyKey {
  public static let liveValue: CheckInRepository = .live

  /// GRDB-backed: `save` normalizes the date to the Europe/Sofia day and upserts the record (the
  /// `date` PK makes a same-day re-save latest-wins); `current` reads the row for that Sofia day. Maps
  /// via the record-intrinsic `init(domain:)`/`toDomain()` (no inline field mapping).
  public static var live: CheckInRepository {
    CheckInRepository(
      save: { checkIn in
        @Dependency(\.database) var database
        @Dependency(\.calendar) var calendar
        var normalized = checkIn
        normalized.date = calendar.startOfDay(for: checkIn.date)
        let record = CheckInRecord(domain: normalized)
        try await database.write { db in try record.save(db) }
      },
      current: { date in
        @Dependency(\.database) var database
        @Dependency(\.calendar) var calendar
        let day = calendar.startOfDay(for: date)
        let record = try await database.read { db in
          try CheckInRecord.fetchOne(db, key: day)
        }
        return record?.toDomain()
      }
    )
  }
}
