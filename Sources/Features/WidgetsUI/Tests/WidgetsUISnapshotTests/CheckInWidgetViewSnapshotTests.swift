// CheckInWidgetView snapshots — the Phase 21.5 check-in nudge in its unlogged, logged, and stale
// (yesterday's logged state past the Sofia rollover → renders the unlogged nudge) states, light +
// dark on the single reference device, each framed to a small-widget-ish square on
// `.coachBackground` (the SkeletonWidgetView convention — WidgetKit configurations aren't
// renderable by swift-snapshot-testing). `#if canImport(UIKit)`-guarded so it compiles to an empty
// module on the macOS host. Runs on the iOS 26 simulator via `make test-snapshots`.

#if canImport(UIKit)
  import CoachCore
  import CoachTestSupport
  import DesignSystem
  import Foundation
  import SnapshotTesting
  import SwiftUI
  import Testing
  import WidgetSnapshotClient
  import WidgetsUI

  @MainActor
  struct CheckInWidgetViewSnapshotTests {
    /// 2026-07-24 00:00 Europe/Sofia (2026-07-23 21:00 UTC) — a fixed instant so nothing drifts.
    private let today = Date(timeIntervalSince1970: 1_784_840_400)
    /// The prior Sofia day — the stale case's state date.
    private let yesterday = Date(timeIntervalSince1970: 1_784_840_400 - 86_400)

    private func framed(_ view: some View) -> some View {
      view
        .frame(width: 170, height: 170)
        .background(Color.coachBackground)
    }

    @Test func test_unlogged() {
      assertCoachSnapshot(
        of: framed(CheckInWidgetView(checkIn: nil, now: today))
      )
    }

    @Test func test_logged() {
      assertCoachSnapshot(
        of: framed(CheckInWidgetView(
          checkIn: WidgetCheckInState(date: today, logged: true, source: .widget), now: today
        ))
      )
    }

    /// Yesterday's logged state past the Sofia rollover — must render the unlogged nudge again.
    @Test func test_stale() {
      assertCoachSnapshot(
        of: framed(CheckInWidgetView(
          checkIn: WidgetCheckInState(date: yesterday, logged: true, source: .app), now: today
        ))
      )
    }
  }
#endif
