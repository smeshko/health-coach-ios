// WeeklyWidgetView snapshots — the Phase 21.4 plan-only weekly overview in its normal, deload, and
// stale states, light + dark on the single reference device, each framed to a medium-widget-ish
// rect on `.coachBackground` (WidgetKit configurations aren't renderable by swift-snapshot-testing).
// `#if canImport(UIKit)`-guarded so it compiles to an empty module on the macOS host. Runs on the
// iOS 26 simulator via `make test-snapshots`.

#if canImport(UIKit)
  import CoachTestSupport
  import DesignSystem
  import DomainModels
  import Foundation
  import SnapshotTesting
  import SwiftUI
  import Testing
  import WidgetSnapshotClient
  import WidgetsUI

  @MainActor
  struct WeeklyWidgetViewSnapshotTests {
    private func framed(_ view: some View) -> some View {
      view
        .frame(width: 364, height: 170)
        .background(Color.coachBackground)
    }

    /// A full weekly section: every optional set on the normal week; the deload variant drops the
    /// long run (a typical deload prescription) and flags `deload`.
    private func makeWeekly(deload: Bool) -> WidgetWeeklySnapshot {
      WidgetWeeklySnapshot(
        isoWeek: "2026-W30",
        budgets: WeeklyBudgets(
          hardDays: 2, strengthSessions: 3, longRunKm: deload ? nil : 14, deload: deload
        ),
        targets: WeeklyTargets(
          totalRunKm: 30, easyRunRatio: 0.8, strengthSessions: 3, hardDays: 2, cadenceSpm: 170
        ),
        coreSessions: [
          PlannedSession(
            card: .longRun, tier: .core, intensity: .easy, isHardDay: false, suggestedDay: .sat
          ),
          PlannedSession(
            card: .threshold, tier: .core, intensity: .quality, isHardDay: true, suggestedDay: .tue
          ),
          PlannedSession(
            card: .strengthLower, tier: .core, intensity: .quality, isHardDay: false,
            suggestedDay: .thu
          ),
          PlannedSession(card: .easyRun, tier: .core, intensity: .easy, isHardDay: false),
        ]
      )
    }

    @Test func test_normal() {
      assertCoachSnapshot(
        of: framed(WeeklyWidgetView(weekly: makeWeekly(deload: false), isStale: false))
      )
    }

    @Test func test_deload() {
      assertCoachSnapshot(
        of: framed(WeeklyWidgetView(weekly: makeWeekly(deload: true), isStale: false))
      )
    }

    @Test func test_stale() {
      assertCoachSnapshot(
        of: framed(WeeklyWidgetView(weekly: makeWeekly(deload: false), isStale: true))
      )
    }
  }
#endif
