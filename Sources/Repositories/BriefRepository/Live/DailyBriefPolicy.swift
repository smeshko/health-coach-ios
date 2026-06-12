import APIClient
import BriefRepository
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
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

  let today = sofiaToday()

  if !refresh {
    let cached = try await database.read { db in
      try DailyBriefRecord.fetchOne(db, key: today)
    }
    if let cached {
      return try cached.toDomain()
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
  return domain
}
