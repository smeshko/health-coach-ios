import APIClient
import BriefRepository
import CoachCore
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import PersistenceModels
import WireDomainMapping
import WireModels

/// Format an `ISOWeek` as the canonical openapi `YYYY-Www` string (zero-padded week, e.g. `2026-W07`).
/// `CoachCore.ISOWeek` ships no `wireString` (1.2), so this `BriefRepositoryLive`-local helper bridges
/// `ISOWeek` → the `WeeklyPlanRecord` PK / `APIClient.weeklyBrief` arg `String` (DECISIONS #4).
func isoWeekKey(_ week: ISOWeek) -> String {
  String(format: "%04d-W%02d", week.year, week.week)
}

/// The weekly get-or-generate, sync-gated cache policy — the same shape as daily, keyed by the
/// Europe/Sofia ISO week (`WeeklyPlanRecord` PK = `isoWeek` string). `nil` `isoWeek` = the current
/// Sofia week (the server resolves it); a specific week passes its formatted `YYYY-Www` as the API
/// arg so client and server agree on the period.
func weeklyPlanPolicy(isoWeek: ISOWeek?, refresh: Bool) async throws -> DomainModels.WeeklyPlan {
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.database) var database

  let week = isoWeek ?? ISOWeek.current
  let key = isoWeekKey(week)

  if !refresh {
    let cached = try await database.read { db in
      try WeeklyPlanRecord.fetchOne(db, key: key)
    }
    if let cached {
      return try cached.toDomain()
    }
  }

  try await requireSyncedWatermark()

  // `nil` for the current week (server resolves it); the formatted key for a specific requested week.
  let apiArg: String? = isoWeek == nil ? nil : key

  let dto: WireModels.WeeklyPlan
  do {
    dto = try await apiClient.weeklyBrief(apiArg, refresh)
  } catch let apiError as APIError {
    let hasPriorBrief = try await database.read { db in try WeeklyPlanRecord.fetchCount(db) > 0 }
    throw briefError(from: apiError, hasPriorBrief: hasPriorBrief)
  }

  let domain = domainWeeklyPlan(dto)

  try await database.write { db in
    try WeeklyPlanRecord(domain: domain).save(db)
  }
  return domain
}
