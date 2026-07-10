import APIClient
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
import LogClient
import PersistenceModels
import ProfileRepository
import WireDomainMapping
import WireModels

extension ProfileRepository: DependencyKey {
  /// The network + GRDB live value. Cache-first profile fetch (Decision 1). The composition root
  /// installs it (optionally wrapped by the 4.1 `routed(dev:)`).
  public static let liveValue: ProfileRepository = .live()

  /// Builds the live value. Shared by `liveValue` and tests.
  static func live() -> ProfileRepository {
    ProfileRepository(
      profile: { try await fetchProfile() },
      zones: { try await fetchProfile().zones }
    )
  }
}

/// Cache-first fetch (Decision 1): serve the single cached `ProfileRecord` when present. On a miss —
/// including an undecodable cached row, which is deleted and degraded to a miss (Phase 19.2 D2) —
/// fetch `GET /profile` and persist. `ProfileResponse` is the canonical `DomainModels.Profile`
/// (Phase 11.3 — no mapping layer), so the decoded value is the domain value. An `APIError` maps to a
/// domain `ProfileRepositoryError.fetchFailed`.
private func fetchProfile() async throws -> DomainModels.Profile {
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.database) var database
  @Dependency(\.log) var log

  let cached = try await database.read { db in try ProfileRecord.fetchOne(db, key: 1) }
  if let cached {
    do {
      return try cached.toDomain()
    } catch {
      // An undecodable singleton row is deleted eagerly (Phase 19.2 D2 — its *existence* is what
      // blocks the miss path), then the call falls through to the plain first-fetch path below. The
      // catch stays narrow: only the row decode degrades; DB read failures keep propagating (18.4
      // discrimination — transient DB trouble is not row corruption).
      log.notice(
        "Cached profile failed to decode — deleting the row and refetching",
        category: .http,
        metadata: ["error": String(describing: error)]
      )
      _ = try await database.write { db in try ProfileRecord.deleteOne(db, key: 1) }
    }
  }

  let domain: DomainModels.Profile
  do {
    domain = try await apiClient.profile()
  } catch let apiError as APIError {
    // A failed fetch surfaces a domain error; the previously cached profile (if any) is left intact
    // and still serves on the next cache-first `profile()` call.
    throw ProfileRepositoryError.fetchFailed(reason: "\(apiError)")
  }

  try await database.write { db in try ProfileRecord(domain: domain).save(db) }
  return domain
}
