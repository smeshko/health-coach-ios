// MacrosWidgetView snapshots (Phase 21.3) — small/medium × with/without yesterday's intake × stale,
// light + dark on the single reference device, framed like the session widget's families. States go
// through `MacrosWidgetState.make` so the footer presence and the Sofia staleness rule are the
// derivation under test. The with-intake fixtures cover both protein markers (small ✓, medium ✗).
// `#if canImport(UIKit)`-guarded; runs on the iOS 26 simulator via `make test-snapshots`.

#if canImport(UIKit)
  import CoachTestSupport
  import DesignSystem
  import DomainModels
  import Foundation
  import SnapshotTesting
  import SwiftUI
  import Testing
  import WidgetsUI
  import WidgetSnapshotClient

  @MainActor
  struct MacrosWidgetViewSnapshotTests {
    /// 2026-07-24 00:00 Europe/Sofia (2026-07-23 21:00 UTC) — the brief's Sofia day.
    private let briefDate = Date(timeIntervalSince1970: 1_784_840_400)
    /// Mid-morning the same Sofia day.
    private let sameDay = Date(timeIntervalSince1970: 1_784_840_400 + 9 * 3600)
    /// 00:10 the NEXT Sofia day — past midnight with no fresh brief.
    private let nextDay = Date(timeIntervalSince1970: 1_784_840_400 + 24 * 3600 + 600)

    private func makeDaily(intakeYesterday: IntakeSummary?) -> WidgetDailySnapshot {
      WidgetDailySnapshot(
        date: briefDate,
        readiness: Readiness(score: 82, band: .green),
        safetyGate: SafetyGate(triggered: false),
        plannedSession: SessionBlock(
          card: .easyRun, intensity: .easy, zoneTarget: .z2, durationMinLow: 40, durationMinHigh: 50
        ),
        macroFocus: MacroFocus(
          dayType: .hard, caloriesKcal: 2700, proteinG: 160, carbsG: 320,
          fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.0
        ),
        intakeYesterday: intakeYesterday
      )
    }

    private func makeIntake(proteinHit: Bool) -> IntakeSummary {
      IntakeSummary(
        date: briefDate.addingTimeInterval(-86_400),
        caloriesKcal: 2500,
        vsTarget: IntakeVsTarget(caloriesPct: 0.92, proteinHit: proteinHit)
      )
    }

    private func framed(_ state: MacrosWidgetState, _ layout: MacrosWidgetView.Layout) -> some View {
      MacrosWidgetView(state: state, layout: layout)
        .frame(width: layout == .small ? 170 : 364, height: 170)
        .background(Color.coachBackground)
    }

    // MARK: - systemSmall

    @Test func test_small_withIntake() {
      let state = MacrosWidgetState.make(
        daily: makeDaily(intakeYesterday: makeIntake(proteinHit: true)), now: sameDay
      )
      assertCoachSnapshot(of: framed(state, .small))
    }

    @Test func test_small_withoutIntake() {
      let state = MacrosWidgetState.make(daily: makeDaily(intakeYesterday: nil), now: sameDay)
      assertCoachSnapshot(of: framed(state, .small))
    }

    @Test func test_small_stale() {
      let state = MacrosWidgetState.make(
        daily: makeDaily(intakeYesterday: makeIntake(proteinHit: true)), now: nextDay
      )
      assertCoachSnapshot(of: framed(state, .small))
    }

    // MARK: - systemMedium

    @Test func test_medium_withIntake() {
      let state = MacrosWidgetState.make(
        daily: makeDaily(intakeYesterday: makeIntake(proteinHit: false)), now: sameDay
      )
      assertCoachSnapshot(of: framed(state, .medium))
    }

    @Test func test_medium_withoutIntake() {
      let state = MacrosWidgetState.make(daily: makeDaily(intakeYesterday: nil), now: sameDay)
      assertCoachSnapshot(of: framed(state, .medium))
    }

    @Test func test_medium_stale() {
      let state = MacrosWidgetState.make(
        daily: makeDaily(intakeYesterday: makeIntake(proteinHit: true)), now: nextDay
      )
      assertCoachSnapshot(of: framed(state, .medium))
    }
  }
#endif
