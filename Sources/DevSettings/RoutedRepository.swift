import SampleData

/// Per-call mock/live routing helper for repository `routed(_:)` factories.
///
/// Each repository ships its own `static func routed(_ dev: DevSettings) -> Self` (DECISIONS #2 — a
/// per-repo static factory, NOT one generic `Routed<Repo>` wrapper, because swift-dependencies stored
/// closures can't be generic). Per closure it calls `devRoute` (or inlines the same branch), which
/// reads `dev.useMockData()` / `dev.scenario(_:)` on **every call** — so flipping the flag at runtime
/// switches delegation instantly, with no relaunch and no re-construction of the routed value
/// (D25 "no relaunch"; ARCHITECTURE §7.1).
///
/// RELEASE: each repo wraps `routed` in `#if DEBUG` / `#else return .live`, so the mock arm is
/// compiled out and `devRoute` is only ever reached on the DEBUG path. (Defensively, when
/// `useMockData()` is `false` — always, in RELEASE — `devRoute` takes the `live` arm anyway.)
///
/// Convention each repository follows (authored on its interface in Phases 4.2–4.5):
/// ```swift
/// extension BriefRepository {
///   static func routed(_ dev: DevSettings) -> Self {
///     #if DEBUG
///     let live = Self.live
///     return Self(
///       dailyBrief: { refresh in
///         try await devRoute(
///           dev, .dailyBrief,
///           live: { try await live.dailyBrief(refresh) },
///           mock: { scenario in try await Self.mock(scenario: scenario).dailyBrief(refresh) }
///         )
///       }
///       // …weeklyPlan etc., each keyed by its own DevEndpoint
///     )
///     #else
///     return .live // mock branch compiled out
///     #endif
///   }
/// }
/// ```
@inlinable
public func devRoute<R>(
  _ dev: DevSettings,
  _ endpoint: DevEndpoint,
  live: @Sendable () async throws -> R,
  mock: @Sendable (SampleScenario) async throws -> R
) async rethrows -> R {
  if dev.useMockData() {
    return try await mock(dev.scenario(endpoint))
  }
  return try await live()
}
