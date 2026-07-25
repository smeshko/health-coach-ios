import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import WidgetSnapshotClient

extension CheckInRepository: DependencyKey {
  public static let liveValue: CheckInRepository = .live

  /// GRDB-backed: `save` normalizes the date to the Europe/Sofia day and upserts the record (the
  /// `date` PK makes a same-day re-save latest-wins); `current` reads the row for that Sofia day. Maps
  /// via the record-intrinsic `init(domain:)`/`toDomain()` (no inline field mapping). `save` also
  /// mirrors the logged state into the widget snapshot (Phase 21.5) through the client INTERFACE —
  /// fire-and-forget, never a save failure. `drainWidgetInbox` persists the widget's pending
  /// all-clears with existing-record precedence (a pending entry never overwrites a same-day row).
  public static var live: CheckInRepository {
    CheckInRepository(
      save: { checkIn in
        @Dependency(\.database) var database
        @Dependency(\.calendar) var calendar
        @Dependency(\.widgetSnapshot) var widgetSnapshot
        var normalized = checkIn
        normalized.date = calendar.startOfDay(for: checkIn.date)
        let record = CheckInRecord(domain: normalized)
        try await database.write { db in try record.save(db) }
        // The widget mirror (Phase 21.5): today is logged in-app. The snapshot merge keeps a
        // later-day state, so a backdated save can't stomp the widget's current day.
        await widgetSnapshot.updateCheckIn(
          WidgetCheckInState(date: normalized.date, logged: true, source: .app)
        )
      },
      current: { date in
        @Dependency(\.database) var database
        @Dependency(\.calendar) var calendar
        let day = calendar.startOfDay(for: date)
        let record = try await database.read { db in
          try CheckInRecord.fetchOne(db, key: day)
        }
        return record?.toDomain()
      },
      drainWidgetInbox: {
        @Dependency(\.database) var database
        @Dependency(\.calendar) var calendar
        @Dependency(\.widgetSnapshot) var widgetSnapshot
        let pending = await widgetSnapshot.pendingCheckIns()
        guard !pending.isEmpty else { return }
        for checkIn in pending {
          var normalized = checkIn
          normalized.date = calendar.startOfDay(for: checkIn.date)
          // Precedence: an existing record for the Sofia day — an in-app check-in, or a previous
          // drain — wins; the pending all-clear must never overwrite it. This same guard is what
          // makes a re-drain idempotent even if clearing the inbox fails.
          let existing = try await database.read { [day = normalized.date] db in
            try CheckInRecord.fetchOne(db, key: day)
          }
          guard existing == nil else { continue }
          let record = CheckInRecord(domain: normalized)
          try await database.write { db in try record.save(db) }
          // No snapshot write here: the widget intent already flipped the state to logged
          // (`source: .widget`) when it appended the entry.
        }
        await widgetSnapshot.clearPendingCheckIns()
      }
    )
  }
}
