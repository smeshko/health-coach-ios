import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels

extension SessionSelectionRepository: DependencyKey {
  public static let liveValue: SessionSelectionRepository = .live

  /// GRDB-backed: `save` normalizes the date to the Europe/Sofia day and upserts the record (the `date`
  /// PK makes a same-day re-save latest-wins); `current` reads the row for that Sofia day and decodes its
  /// block. Maps via the record-intrinsic `init(date:block:)`/`selectedBlock()` (no inline blob coding).
  public static var live: SessionSelectionRepository {
    SessionSelectionRepository(
      save: { block, date in
        @Dependency(\.database) var database
        @Dependency(\.calendar) var calendar
        let day = calendar.startOfDay(for: date)
        let record = try SessionSelectionRecord(date: day, block: block)
        try await database.write { db in try record.save(db) }
      },
      current: { date in
        @Dependency(\.database) var database
        @Dependency(\.calendar) var calendar
        let day = calendar.startOfDay(for: date)
        let record = try await database.read { db in
          try SessionSelectionRecord.fetchOne(db, key: day)
        }
        return try record?.selectedBlock()
      }
    )
  }
}
