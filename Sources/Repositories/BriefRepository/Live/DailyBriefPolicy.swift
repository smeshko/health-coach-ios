import APIClient
import BriefRepository
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import LogClient
import PersistenceModels
import WidgetSnapshotClient
import WireDomainMapping
import WireModels

/// The daily get-or-generate, sync-gated cache policy (D23, ARCHITECTURE §7):
/// 1. Serve today's (Europe/Sofia) cached brief with **no network call** when `refresh == false`.
/// 2. On a miss (or refresh), require a successful prior sync — else `.syncRequired`.
/// 3. Generate via `APIClient`, map DTO→domain via `WireDomainMapping`, persist via `Database`.
/// `save` upserts on the `date` PK, so `refresh` overwrites the same-day row.
func dailyBriefPolicy(refresh: Bool) async throws -> DomainModels.DailyBrief {
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.database) var database
  @Dependency(\.log) var log
  @Dependency(\.widgetSnapshot) var widgetSnapshot

  let today = sofiaToday()

  if !refresh {
    let cached = try await database.read { db in
      try DailyBriefRecord.fetchOne(db, key: today)
    }
    if let cached {
      do {
        return try cached.toDomain()
      } catch {
        // A corrupt/format-drifted row is a cache MISS, not a fatal error (Phase 19.2 D2): fall
        // through to the generate path — its `save` overwrites the same-day row (same `date` PK).
        // The catch stays narrow: only the row decode degrades; DB read failures keep propagating.
        log.notice(
          "Cached daily brief failed to decode — treating as a cache miss",
          category: .http,
          metadata: ["error": String(describing: error)]
        )
      }
    }
  }

  try await requireSyncedWatermark()

  let dto: WireModels.DailyBrief
  do {
    dto = try await apiClient.dailyBrief(nil, refresh)
  } catch let apiError as APIError {
    // "First-ever" (the 500 fork) = no daily brief has ever been cached.
    let hasPriorBrief = try await database.read { db in try DailyBriefRecord.fetchCount(db) > 0 }
    throw briefError(from: apiError, hasPriorBrief: hasPriorBrief)
  }

  let domain = domainDailyBrief(dto)

  try await database.write { db in
    try DailyBriefRecord(domain: domain).save(db)
  }
  // The Phase 21.1 widget mirror — fired only where the daily cache is WRITTEN (a cache hit was
  // mirrored when its row was written). Non-throwing by contract, so the brief path can't fail on it.
  await widgetSnapshot.updateDailyBrief(domain)
  return domain
}

/// The pure same-day cache **peek** (Phase 12.1, DECISIONS D1) backing `BriefRepository.cachedDailyBrief`:
/// read today's (Europe/Sofia) `DailyBriefRecord` straight from the DB and map it to domain, returning
/// `nil` on a miss. **No `APIClient`, no `requireSyncedWatermark()`, never generates** — that is the
/// whole point of the peek versus `dailyBriefPolicy` (get-or-generate). The day key (`sofiaToday()`) and
/// the `toDomain()` mapping are shared with `dailyBriefPolicy` so the peek and the get-or-generate read
/// agree on the same-day row.
func cachedDailyBriefPolicy() async throws -> DomainModels.DailyBrief? {
  @Dependency(\.database) var database
  @Dependency(\.log) var log

  let cached = try await database.read { db in
    try DailyBriefRecord.fetchOne(db, key: sofiaToday())
  }
  guard let cached else { return nil }
  do {
    return try cached.toDomain()
  } catch {
    // A corrupt row is "no usable cache" (Phase 19.2 D2): the peek returns `nil` — it never
    // generates or repairs (the get-or-generate path owns the overwrite).
    log.notice(
      "Cached daily brief failed to decode — peek reports no usable cache",
      category: .http,
      metadata: ["error": String(describing: error)]
    )
    return nil
  }
}
