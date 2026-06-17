// StrengthTestView snapshot — the strength-test input screen in its due (callout shown) and not-due
// states, light + dark on the single reference device (`Strength Input Screen.png`). `#if canImport(UIKit)`-
// guarded so it compiles to an empty module on the macOS host (SwiftUI image snapshots are UIKit-only).
// Runs on the iOS 26 simulator via `make test-snapshots`.
//
// State is pre-seeded directly (not via the async `.onAppear`), so the captured image is deterministic;
// `current` is pinned to values matching the seed so even a late `loaded` leaves the state unchanged.

#if canImport(UIKit)
  import CoachCore
  import CoachTestSupport
  import ComposableArchitecture
  import DomainModels
  import Foundation
  import SnapshotTesting
  import SwiftUI
  import Testing

  @testable import StrengthTestFeature

  @MainActor
  struct StrengthTestViewSnapshotTests {
    /// Noon on a wall-clock day in Europe/Sofia.
    private func sofiaDate(year: Int, month: Int, day: Int) -> Date {
      var components = DateComponents()
      components.year = year
      components.month = month
      components.day = day
      components.hour = 12
      return Calendar.europeSofia.date(from: components)!
    }

    @Test func test_due() {
      // now: 2026-06-10 (ISO week 24); last test in the prior week → due, callout shown, 42/11 seeded.
      let now = sofiaDate(year: 2026, month: 6, day: 10)
      let last = DomainModels.StrengthTest(
        date: sofiaDate(year: 2026, month: 6, day: 1), maxPushups: 42, maxPullups: 11
      )
      let view = withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(now)
        $0.strengthTestRepository.current = { _ in last }
      } operation: {
        StrengthTestView(
          store: Store(initialState: .init(maxPushups: 42, maxPullups: 11, isDue: true)) {
            StrengthTestFeature()
          }
        )
      }
      assertCoachSnapshot(of: view)
    }

    @Test func test_notDue() {
      // now: 2026-06-10; last test earlier this same ISO week → not due, no callout, 30/8 seeded.
      let now = sofiaDate(year: 2026, month: 6, day: 10)
      let last = DomainModels.StrengthTest(
        date: sofiaDate(year: 2026, month: 6, day: 8), maxPushups: 30, maxPullups: 8
      )
      let view = withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(now)
        $0.strengthTestRepository.current = { _ in last }
      } operation: {
        StrengthTestView(
          store: Store(initialState: .init(maxPushups: 30, maxPullups: 8, isDue: false)) {
            StrengthTestFeature()
          }
        )
      }
      assertCoachSnapshot(of: view)
    }
  }
#endif
