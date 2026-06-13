import SampleData

/// The per-endpoint key the DevSettings scenario map is keyed by — one case per data source that has
/// a mock/live fork (ARCHITECTURE §7.1's `dev.scenario(.dailyBrief)` sketch). Each endpoint maps to a
/// default `SampleData.SampleScenario` (the single source of sample truth, Phase 2.3).
///
/// `.checkIn` / `.strengthTest` are intentionally **absent**: those repositories are local-only
/// (no remote fork to mock against), so they have no scenario selection — see Phase 4.4.
public enum DevEndpoint: String, CaseIterable, Sendable, Hashable {
  case dailyBrief
  case weeklyPlan
  case profile
  case sync

  /// The fixture served for this endpoint when no explicit scenario has been selected.
  /// Referenced by symbol so a `SampleScenario` rename/removal is a compile error.
  public var defaultScenario: SampleScenario {
    switch self {
    case .dailyBrief: .dailyBriefGreen
    // `.weeklyPlanDeload` is the only weekly fixture Phase 2.3 ships (no non-deload weekly scenario).
    case .weeklyPlan: .weeklyPlanDeload
    case .profile: .profile
    case .sync: .syncResponse
    }
  }

  /// Every `SampleScenario` that belongs to this endpoint. Lets the dev menu list **only** an endpoint's
  /// own fixtures when picking a scenario for it (instead of all `SampleScenario.allCases`). Invariant:
  /// the per-endpoint lists **partition** `SampleScenario.allCases` (each scenario belongs to exactly one
  /// endpoint) and each always contains `defaultScenario` — guarded by `DevEndpointTests`.
  public var scenarios: [SampleScenario] {
    switch self {
    case .dailyBrief:
      [
        .dailyBriefGreen, .dailyBriefAmber, .dailyBriefRed, .dailyBriefRestGIFlare,
        .dailyBriefRestIllness, .dailyBriefRestKnee, .dailyBriefNoFood,
      ]
    case .weeklyPlan: [.weeklyPlanDeload]
    case .profile: [.profile]
    case .sync: [.syncResponse]
    }
  }
}
