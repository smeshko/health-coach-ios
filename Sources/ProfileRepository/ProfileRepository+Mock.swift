import DomainModels
import SampleData

public extension ProfileRepository {
  /// A fixture-backed profile repository — returns the canned `SampleData.profile` (athlete, zones,
  /// thresholds, meta) with no live deps (D25/§7.1). `scenario` is `SampleData.SampleScenario` (the
  /// single source of sample truth, 2.3) so Phase 4.1's `routed(dev:)` wrapper — which calls
  /// `Self.mock(scenario: dev.scenario(.profile))` — composes it; the profile fixture is the only
  /// relevant case, so other scenarios map to the same canned profile.
  static func mock(scenario _: SampleScenario) -> ProfileRepository {
    ProfileRepository(
      profile: { try SampleData.profile().domain },
      refresh: { try SampleData.profile().domain },
      zones: { try SampleData.profile().domain.zones },
      recomputeNotices: {
        AsyncStream { continuation in
          continuation.yield(RecomputeNotice(week: "2026-W04"))
          continuation.finish()
        }
      },
      noteRecompute: { _ in }
    )
  }
}
