import APIClient
import Database
import Dependencies
import DomainModels
import Foundation
import GRDB
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

/// Cache-first fetch (Decision 1): serve the single cached `ProfileRecord` when present. On a miss,
/// fetch `GET /profile` and persist. `ProfileResponse` is the canonical `DomainModels.Profile`
/// (Phase 11.3 — no mapping layer), so the decoded value is the domain value. An `APIError` maps to a
/// domain `ProfileRepositoryError.fetchFailed`.
private func fetchProfile() async throws -> DomainModels.Profile {
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.database) var database

  let cached = try await database.read { db in try ProfileRecord.fetchOne(db, key: 1) }
  if let cached {
    return try cached.toDomain()
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
