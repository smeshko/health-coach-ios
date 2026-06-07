import BriefRepository
import CoachCore
import Database
import Dependencies
import Foundation
import GRDB
import PersistenceModels

/// The canonical Europe/Sofia start-of-day for the injected "now" — the daily cache key. Matches the
/// `DailyBriefRecord.date` PK, which `DailyBriefRecord(domain:)` derives from the server-stamped
/// Sofia-midnight `domain.date` (the cache-key↔PK contract — PLAN Decisions).
func sofiaToday() -> Date {
  @Dependency(\.calendar) var calendar
  @Dependency(\.date) var date
  return calendar.startOfDay(for: date.now)
}

/// Throws `BriefError.syncRequired` unless a successful sync watermark exists. Read **through the
/// `Database` interface** (the `SyncWatermarkRecord` `SyncRepository` writes) — never a
/// `SyncRepository` import (DECISIONS #2). `serverTime` is non-optional (2.3), so "row exists" is the
/// synced predicate.
func requireSyncedWatermark() async throws {
  @Dependency(\.database) var database
  let synced = try await database.read { db in
    try SyncWatermarkRecord.fetchOne(db, key: 1) != nil
  }
  guard synced else { throw BriefError.syncRequired }
}
