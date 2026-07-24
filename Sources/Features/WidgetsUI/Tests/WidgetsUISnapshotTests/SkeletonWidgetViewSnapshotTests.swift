// SkeletonWidgetView snapshots — the Phase 21.1 pipeline-proof widget view in its populated and
// stale states, light + dark on the single reference device, each framed to a small-widget-ish
// square on `.coachBackground` (WidgetKit configurations aren't renderable by swift-snapshot-testing;
// the plain view is what later phases iterate on). `#if canImport(UIKit)`-guarded so it compiles to
// an empty module on the macOS host. Runs on the iOS 26 simulator via `make test-snapshots`.

#if canImport(UIKit)
  import CoachTestSupport
  import DesignSystem
  import Foundation
  import SnapshotTesting
  import SwiftUI
  import Testing
  import WidgetsUI

  @MainActor
  struct SkeletonWidgetViewSnapshotTests {
    /// 2026-07-24 00:00 Europe/Sofia (2026-07-23 21:00 UTC) — a fixed instant so the rendered date
    /// label never drifts.
    private let fixedDate = Date(timeIntervalSince1970: 1_784_840_400)

    private func framed(_ view: some View) -> some View {
      view
        .frame(width: 170, height: 170)
        .background(Color.coachBackground)
    }

    @Test func test_populated() {
      assertCoachSnapshot(
        of: framed(SkeletonWidgetView(date: fixedDate, readinessScore: 82, isStale: false))
      )
    }

    @Test func test_stale() {
      assertCoachSnapshot(
        of: framed(SkeletonWidgetView(date: fixedDate, readinessScore: 82, isStale: true))
      )
    }
  }
#endif
