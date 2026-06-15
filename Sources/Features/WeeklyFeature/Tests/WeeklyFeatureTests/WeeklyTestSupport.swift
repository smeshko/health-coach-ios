import Clocks
import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import SampleData

@testable import WeeklyFeature

/// Shared fixtures + the isolated `TestStore` factory for the WeeklyFeature suites (extracted so each
/// suite stays within the type-body length cap and reuses one store setup).
enum WeeklyTestSupport {
  /// A test store with the Europe/Sofia frame pinned, a fresh appStorage suite (so the `@Shared` watermark
  /// never leaks between parallel tests / real UserDefaults), and an `ImmediateClock` by default (tests
  /// that drive the debounce/cancellation override `\.continuousClock` with a `TestClock`).
  ///
  /// The unique suite is bound around the **initialState** evaluation too: `TestStore` evaluates its
  /// `initialState` autoclosure inside this same `withDependencies` scope, so the initial state and the
  /// reducer share one dependency context (and one `PersistentReferences` cache) bound to this suite —
  /// no split-context contamination.
  @MainActor
  static func makeStore(
    date: Date,
    _ prepare: @escaping (inout DependencyValues) -> Void
  ) -> TestStoreOf<WeeklyFeature> {
    let suiteName = "weekly-tests-\(UUID().uuidString)"
    let suite = UserDefaults(suiteName: suiteName)!
    suite.removePersistentDomain(forName: suiteName)
    return TestStore(initialState: WeeklyFeature.State()) {
      WeeklyFeature()
    } withDependencies: {
      $0.defaultAppStorage = suite
      $0.useEuropeSofia()
      $0.date = .constant(date)
      $0.continuousClock = ImmediateClock()
      prepare(&$0)
    }
  }

  static func deloadPlan(cached: Bool = false) throws -> DomainModels.WeeklyPlan {
    var plan = try SampleData.weeklyPlan(.weeklyPlanDeload).domain
    plan.cached = cached
    return plan
  }

  static func sampleZones() -> DomainModels.Zones {
    SampleData.sampleProfile.zones
  }

  /// A non-`BriefError` error to exercise the fetch catch-all (a propagated 401 / unexpected throw).
  struct Boom: Error {}

  /// A Europe/Sofia midday instant, host-timezone-independent (mirrors WeeklyCachePolicyTests' helper).
  static func sofiaMidday(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Sofia")!
    return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
  }
}
