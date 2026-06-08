import CheckInRepository
import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels

/// A canned `.mock(scenario:)` selection. The check-in repo has no `SampleData` fixture (Phase 2.3
/// ships none), so the mock builds small local literals — `.logged` returns a canned check-in for the
/// requested day, `.empty` returns `nil` (no check-in logged yet).
public enum CheckInMockScenario: Sendable {
  case logged
  case empty
}

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

  /// Canned values, no live deps — `save` is a no-op; `current` returns the scenario's value.
  public static func mock(scenario: CheckInMockScenario) -> CheckInRepository {
    CheckInRepository(
      save: { _ in },
      current: { date in
        switch scenario {
        case .logged:
          DomainModels.CheckIn(date: date, giSymptoms: false, kneePain: 2, illness: false)
        case .empty:
          nil
        }
      }
    )
  }
}
