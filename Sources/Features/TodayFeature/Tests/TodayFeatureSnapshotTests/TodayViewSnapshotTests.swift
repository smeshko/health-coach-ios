// TodayView snapshots (ARCHITECTURE D16): the three lifecycle chrome states the epic Validation names —
// **loading (`.syncing`)**, **generating**, and **sync-failed** — in light + dark on the single
// reference device, via the shared `CoachTestSupport` harness. The whole body is `#if canImport(UIKit)`-
// guarded so this target compiles to an empty module on the macOS host (so `swift test` stays green); it
// runs on the pinned iOS 26 simulator via `make test-snapshots`.
//
// The shell header reads `@Dependency(\.date)`/`(\.calendar)` for the date subtitle, so each snapshot is
// wrapped in `withDependencies` to pin a fixed Europe/Sofia instant (deterministic references). A
// representative `.ready` snapshot is deferred to 8.2–8.4 (which own the readiness/session/nutrition
// content); this phase snapshots only the lifecycle chrome.

#if canImport(UIKit)
  import CoachCore
  import CoachTestSupport
  import ComposableArchitecture
  import Foundation
  import SnapshotTesting
  import Testing

  @testable import TodayFeature

  @MainActor
  struct TodayViewSnapshotTests {
    /// A fixed wall-clock instant in Europe/Sofia (Friday, June 5 2026) so the date subtitle is stable.
    private func fixedInstant() -> Date {
      var components = DateComponents()
      components.year = 2026
      components.month = 6
      components.day = 5
      components.hour = 9
      return Calendar.europeSofia.date(from: components)!
    }

    private func view(_ state: BriefViewState) -> TodayView {
      TodayView(store: Store(initialState: TodayFeature.State(briefState: state)) { TodayFeature() })
    }

    @Test func test_syncing() {
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: view(.syncing))
      }
    }

    @Test func test_generating() {
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: view(.generating))
      }
    }

    @Test func test_syncFailed() {
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
      } operation: {
        assertCoachSnapshot(of: view(.syncFailed(.network)))
      }
    }
  }
#endif
