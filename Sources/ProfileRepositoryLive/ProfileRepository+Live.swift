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
  /// The network + GRDB live value. Cache-first profile fetch with an event-driven recompute notice
  /// (Decision 1/2). The composition root installs it (optionally wrapped by the 4.1 `routed(dev:)`).
  public static var liveValue: ProfileRepository {
    let recompute = RecomputeStream()
    return ProfileRepository(
      profile: { try await fetchProfile(recompute: recompute, forceRefresh: false) },
      refresh: { try await fetchProfile(recompute: recompute, forceRefresh: true) },
      zones: { try await fetchProfile(recompute: recompute, forceRefresh: false).zones },
      recomputeNotices: { recompute.stream },
      noteRecompute: { week in recompute.emit(RecomputeNotice(week: week)) }
    )
  }
}

/// Owns the recompute `AsyncStream` + its continuation (mirrors `APIClientLive`'s `SessionEvent`
/// stream — the interface exposes the accessor only, so features depend on the interface, §3).
final class RecomputeStream: Sendable {
  let stream: AsyncStream<RecomputeNotice>
  private let continuation: AsyncStream<RecomputeNotice>.Continuation

  init() {
    let (stream, continuation) = AsyncStream.makeStream(of: RecomputeNotice.self)
    self.stream = stream
    self.continuation = continuation
  }

  func emit(_ notice: RecomputeNotice) {
    continuation.yield(notice)
  }
}

/// Cache-first fetch (Decision 1): serve the single cached `ProfileRecord` unless `forceRefresh`. On a
/// miss/refresh, fetch `GET /profile`, map via the pure `domainProfile` (non-throwing), persist, and —
/// when the fetched `constantsRecomputedWeek` differs from the previously cached one — emit a
/// `RecomputeNotice` (Decision 2). An `APIError` maps to a domain `ProfileRepositoryError.fetchFailed`.
private func fetchProfile(
  recompute: RecomputeStream,
  forceRefresh: Bool
) async throws -> DomainModels.Profile {
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.database) var database

  let cached = try await database.read { db in try ProfileRecord.fetchOne(db, key: 1) }
  if !forceRefresh, let cached {
    return try cached.toDomain()
  }
  let previousWeek = try cached?.toDomain().meta.constantsRecomputedWeek

  let dto: WireModels.ProfileResponse
  do {
    dto = try await apiClient.profile()
  } catch let apiError as APIError {
    // A failed fetch surfaces a domain error; the previously cached profile (if any) is left intact
    // and still serves on the next cache-first `profile()` call.
    throw ProfileRepositoryError.fetchFailed(reason: "\(apiError)")
  }
  let domain = domainProfile(dto)

  try await database.write { db in try ProfileRecord(domain: domain).save(db) }

  if let newWeek = domain.meta.constantsRecomputedWeek, newWeek != previousWeek {
    recompute.emit(RecomputeNotice(week: newWeek))
  }
  return domain
}
