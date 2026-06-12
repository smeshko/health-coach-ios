import Dependencies
import DomainModels
import SampleData

/// The domain error a profile fetch surfaces. The interface never imports `APIError`/`WireModels`, so
/// the wire error is carried as a domain-safe `reason` string (mapped in `ProfileRepositoryLive`).
public enum ProfileRepositoryError: Error, Equatable, Sendable {
  case fetchFailed(reason: String)
}

/// The profile-constants repository (ARCHITECTURE §7, §4.3). Cache-first: `profile()` serves the
/// cached profile (refetch is event-driven on a recompute, not a TTL — Decision 1); `zones()` exposes
/// the five HR zone bpm ranges the `ZoneChip` consumes.
public struct ProfileRepository: Sendable {
  public var profile: @Sendable () async throws -> DomainModels.Profile
  public var zones: @Sendable () async throws -> DomainModels.Zones

  public init(
    profile: @escaping @Sendable () async throws -> DomainModels.Profile,
    zones: @escaping @Sendable () async throws -> DomainModels.Zones
  ) {
    self.profile = profile
    self.zones = zones
  }
}

extension ProfileRepository: TestDependencyKey {
  /// The canned `SampleData` profile, no live deps.
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
