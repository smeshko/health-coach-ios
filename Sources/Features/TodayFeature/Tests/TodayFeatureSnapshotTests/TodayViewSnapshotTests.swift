// TodayView snapshots (ARCHITECTURE D16): the lifecycle chrome states — the redesigned **loading
// (`.syncing`)** and **generating** states (`2 ·`/`3 · Loading` mockups), **sync-failed**, and the
// redesigned **check-in screen** (`1 · Daily Check-in.png`, the `.checkInRequired` gate — no section
// toggle until a brief is available) — in light + dark on the single reference device, via the shared
// `CoachTestSupport` harness. The whole body is `#if canImport(UIKit)`-guarded so this target compiles
// to an empty module on the macOS host (so `swift test` stays green); it runs on the pinned iOS 26
// simulator via `make test-snapshots`.
//
// The shell header reads `@Dependency(\.date)`/`(\.calendar)` for the date subtitle, so each snapshot is
// wrapped in `withDependencies` to pin a fixed Europe/Sofia instant (deterministic references). The full
// `.ready` brief content (readiness gauge, session, nutrition) is still 8.2–8.4's; the check-in snapshot
// pins `checkInRepository.current` so the `.task` load is a no-op and the seeded card is captured.

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

    /// 7:02 AM in Europe/Sofia (Friday, June 5 2026) — the check-in footer's "Last saved" stamp.
    private func savedAtInstant() -> Date {
      var components = DateComponents()
      components.year = 2026
      components.month = 6
      components.day = 5
      components.hour = 7
      components.minute = 2
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

    /// The redesigned check-in screen (`1 · Daily Check-in.png`) — the `.checkInRequired` gate (no
    /// section toggle), seeded to the mockup's "2 · Mild" knee pain and a 7:02 AM "Last saved" footer.
    /// `current` is pinned so the card's `.task` load is a no-op and the seeded state is what's captured.
    @Test func test_checkIn() {
      let state = TodayFeature.State(
        briefState: .checkInRequired,
        checkIn: CheckInComponent.State(kneePain: 2, lastSavedAt: savedAtInstant())
      )
      withDependencies {
        $0.calendar = .europeSofia
        $0.date = .constant(fixedInstant())
        $0.checkInRepository.current = { _ in nil }
      } operation: {
        assertCoachSnapshot(of: TodayView(store: Store(initialState: state) { TodayFeature() }))
      }
    }
  }
#endif
