import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import StrengthTestRepository

/// A canned `.mock(scenario:)` selection (no `SampleData` strength fixture exists — Phase 2.3).
public enum StrengthTestMockScenario: Sendable {
  case logged
  case empty
}

extension StrengthTestRepository: DependencyKey {
  public static let liveValue: StrengthTestRepository = .live

  /// GRDB-backed: `save` normalizes to the Europe/Sofia day and upserts (the `date` PK makes a
  /// same-day re-test latest-wins). `current` reads the **most recent** test at-or-before the Sofia
  /// day (`date <= day ORDER BY date DESC LIMIT 1`) — a query, NOT a key fetch, so an earlier-in-week
  /// test is still found. Maps via the record-intrinsic `init(domain:)`/`toDomain()`.
  public static var live: StrengthTestRepository {
    StrengthTestRepository(
      save: { test in
        @Dependency(\.database) var database
        @Dependency(\.calendar) var calendar
        var normalized = test
        normalized.date = calendar.startOfDay(for: test.date)
        let record = StrengthTestRecord(domain: normalized)
        try await database.write { db in try record.save(db) }
      },
      current: { date in
        @Dependency(\.database) var database
        @Dependency(\.calendar) var calendar
        let day = calendar.startOfDay(for: date)
        let record = try await database.read { db in
          try StrengthTestRecord
            .filter(Column("date") <= day)
            .order(Column("date").desc)
            .fetchOne(db)
        }
        return record?.toDomain()
      }
    )
  }

  /// Canned values, no live deps.
  public static func mock(scenario: StrengthTestMockScenario) -> StrengthTestRepository {
    StrengthTestRepository(
      save: { _ in },
      current: { date in
        switch scenario {
        case .logged:
          DomainModels.StrengthTest(date: date, maxPushups: 30, maxPullups: 8)
        case .empty:
          nil
        }
      }
    )
  }
}
