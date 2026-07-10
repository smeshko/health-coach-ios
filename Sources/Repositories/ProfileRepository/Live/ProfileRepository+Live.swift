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

/// Cache-first fetch (Decision 1) with sync-anchored staleness (Phase 19.2 D1): a decodable cached
/// `ProfileRecord` serves without network only while its `syncServerTime` stamp *equals* the current
/// watermark `serverTime` — both are copies of the *server's* clock (the device never generates
/// them), so plain equality is a clock-skew-free staleness predicate and ordering comparisons buy
/// nothing. A successful sync advances the watermark, the stamp differs, and the next call refetches
/// `GET /profile` and restamps — that is how a server constants recompute reaches the device. A
/// stale row whose refetch fails stale-serves the cached values (D3 — freshness never buys an
/// outage). On a miss — including an undecodable cached row, which is deleted and degraded to a miss
/// (D2) — fetch `GET /profile` and persist. `ProfileResponse` is the canonical `DomainModels.Profile`
/// (Phase 11.3 — no mapping layer), so the decoded value is the domain value. An `APIError` with no
/// servable cache maps to a domain `ProfileRepositoryError.fetchFailed`.
private func fetchProfile() async throws -> DomainModels.Profile {
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.database) var database
  @Dependency(\.log) var log

  // One read for both the cached row and the watermark: the stamp persisted below is always THIS
  // pre-fetch watermark value, never a re-read at write time — a sync completing mid-`GET /profile`
  // would otherwise stamp a possibly pre-recompute profile with the new `serverTime` and mask the
  // recompute until the following sync. Stamping the pre-fetch value costs at most one redundant
  // refetch and can never mask.
  let (cached, watermark) = try await database.read { db in
    try (ProfileRecord.fetchOne(db, key: 1), SyncWatermarkRecord.fetchOne(db, key: 1))
  }

  // The stale-but-decodable profile, held for stale-serving if the refetch below fails (D3).
  var staleCached: DomainModels.Profile?
  if let cached {
    do {
      let domain = try cached.toDomain()
      if cached.syncServerTime == watermark?.serverTime {
        // Fresh hit (nil == nil covers a never-synced DB + unstamped row): serve, no network.
        return domain
      }
      staleCached = domain
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
    if let staleCached {
      // Stale-serve (D3): zones one recompute old beat no zones; the row keeps its old stamp, so
      // the next call retries the refetch.
      return staleCached
    }
    // A failed first fetch surfaces a domain error; there is nothing usable to serve.
    throw ProfileRepositoryError.fetchFailed(reason: "\(apiError)")
  }

  try await database.write { db in
    try ProfileRecord(domain: domain, syncServerTime: watermark?.serverTime).save(db)
  }
  return domain
}
