import Dependencies
import DomainModels
import SampleData

/// A monthly-recompute notice — the ISO week the server recomputed profile constants in. Emitted on
/// `recomputeNotices()` so a feature can refetch without polling (resolves OPEN-1, §17.1).
public struct RecomputeNotice: Equatable, Sendable {
  public let week: String
  public init(week: String) {
    self.week = week
  }
}

/// The domain error a profile fetch surfaces. The interface never imports `APIError`/`WireModels`, so
/// the wire error is carried as a domain-safe `reason` string (mapped in `ProfileRepositoryLive`).
public enum ProfileRepositoryError: Error, Equatable, Sendable {
  case fetchFailed(reason: String)
}

/// The profile-constants repository (ARCHITECTURE §7, §4.3). Cache-first: `profile()` serves the
/// cached profile (refetch is event-driven on a recompute, not a TTL — Decision 1); `refresh()` forces
/// a fetch + overwrite; `zones()` exposes the five HR zone bpm ranges the `ZoneChip` consumes;
/// `recomputeNotices()` streams a notice when a fetch brings a new `constantsRecomputedWeek`;
/// `noteRecompute(_:)` lets a feature hand off a recompute caught elsewhere (e.g. a weekly brief).
public struct ProfileRepository: Sendable {
  public var profile: @Sendable () async throws -> DomainModels.Profile
  public var refresh: @Sendable () async throws -> DomainModels.Profile
  public var zones: @Sendable () async throws -> DomainModels.Zones
  public var recomputeNotices: @Sendable () -> AsyncStream<RecomputeNotice>
  public var noteRecompute: @Sendable (_ week: String) async -> Void

  public init(
    profile: @escaping @Sendable () async throws -> DomainModels.Profile,
    refresh: @escaping @Sendable () async throws -> DomainModels.Profile,
    zones: @escaping @Sendable () async throws -> DomainModels.Zones,
    recomputeNotices: @escaping @Sendable () -> AsyncStream<RecomputeNotice>,
    noteRecompute: @escaping @Sendable (_ week: String) async -> Void
  ) {
    self.profile = profile
    self.refresh = refresh
    self.zones = zones
    self.recomputeNotices = recomputeNotices
    self.noteRecompute = noteRecompute
  }
}

extension ProfileRepository: TestDependencyKey {
  /// The canned `SampleData` profile, no live deps (yields one canned recompute notice).
  public static var testValue: ProfileRepository {
    .mock(scenario: .profile)
  }

  public static var previewValue: ProfileRepository {
    testValue
  }
}

public extension DependencyValues {
  var profileRepository: ProfileRepository {
    get { self[ProfileRepository.self] }
    set { self[ProfileRepository.self] = newValue }
  }
}
