// SessionWidgetView snapshots (Phase 21.2) — every family × the five states (planned session,
// athlete-selected session, rest card, tripped gate, stale), light + dark on the single reference
// device, each framed to its family's approximate size on `.coachBackground` (WidgetKit
// configurations aren't renderable by swift-snapshot-testing; the plain view is the contract).
// States are built through `SessionWidgetState.make` so the selected-over-planned fallback and the
// Sofia staleness rule are exercised, not just the leaf rendering. `#if canImport(UIKit)`-guarded;
// runs on the iOS 26 simulator via `make test-snapshots`.

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
  struct SessionWidgetViewSnapshotTests {
    /// 2026-07-24 00:00 Europe/Sofia (2026-07-23 21:00 UTC) — the brief's Sofia day.
    private let briefDate = Date(timeIntervalSince1970: 1_784_840_400)
    /// Mid-morning the same Sofia day — the "current" render instant.
    private let sameDay = Date(timeIntervalSince1970: 1_784_840_400 + 9 * 3600)
    /// 00:10 the NEXT Sofia day — past midnight with no fresh brief.
    private let nextDay = Date(timeIntervalSince1970: 1_784_840_400 + 24 * 3600 + 600)

    /// The planned session — an easy Z2 run with an HR cap (zone chip + cap line both render).
    private let planned = SessionBlock(
      card: .easyRun, intensity: .easy, zoneTarget: .z2,
      durationMinLow: 40, durationMinHigh: 50, hrCapBpm: 146
    )
    /// The athlete's pick — a no-zone quality block (badge row degrades to nothing).
    private let selected = SessionBlock(
      card: .strides, intensity: .quality, durationMinLow: 20, durationMinHigh: 30
    )

    private func makeDaily(
      session: SessionBlock,
      selectedSession: SessionBlock? = nil,
      gate: SafetyGate = SafetyGate(triggered: false)
    ) -> WidgetDailySnapshot {
      WidgetDailySnapshot(
        date: briefDate,
        readiness: Readiness(score: 82, band: .green),
        safetyGate: gate,
        plannedSession: session,
        selectedSession: selectedSession,
        macroFocus: MacroFocus(
          dayType: .moderate, caloriesKcal: 2400, proteinG: 150, carbsG: 280,
          fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.0
        )
      )
    }

    // The five derived states.
    private var sessionState: SessionWidgetState {
      .make(daily: makeDaily(session: planned), now: sameDay)
    }

    private var selectedState: SessionWidgetState {
      .make(daily: makeDaily(session: planned, selectedSession: selected), now: sameDay)
    }

    private var restState: SessionWidgetState {
      .make(
        daily: makeDaily(
          session: SessionBlock(card: .rest, intensity: .recovery, durationMinLow: 0, durationMinHigh: 0)
        ),
        now: sameDay
      )
    }

    private var gateState: SessionWidgetState {
      .make(
        daily: makeDaily(
          session: SessionBlock(card: .rest, intensity: .recovery, durationMinLow: 0, durationMinHigh: 0),
          gate: SafetyGate(triggered: true, reasons: [.sleepBelow4h], overrideTo: .rest)
        ),
        now: sameDay
      )
    }

    private var staleState: SessionWidgetState {
      .make(daily: makeDaily(session: planned), now: nextDay)
    }

    private func framed(
      _ state: SessionWidgetState, _ layout: SessionWidgetView.Layout
    ) -> some View {
      let size: CGSize = switch layout {
      case .small: CGSize(width: 170, height: 170)
      case .medium: CGSize(width: 364, height: 170)
      case .inline: CGSize(width: 250, height: 40)
      case .rectangular: CGSize(width: 180, height: 80)
      }
      return SessionWidgetView(state: state, layout: layout)
        .frame(width: size.width, height: size.height)
        .background(Color.coachBackground)
    }

    // MARK: - systemSmall

    @Test func test_small_session() {
      assertCoachSnapshot(of: framed(sessionState, .small))
    }

    @Test func test_small_selected() {
      assertCoachSnapshot(of: framed(selectedState, .small))
    }

    @Test func test_small_rest() {
      assertCoachSnapshot(of: framed(restState, .small))
    }

    @Test func test_small_gate() {
      assertCoachSnapshot(of: framed(gateState, .small))
    }

    @Test func test_small_stale() {
      assertCoachSnapshot(of: framed(staleState, .small))
    }

    // MARK: - systemMedium

    @Test func test_medium_session() {
      assertCoachSnapshot(of: framed(sessionState, .medium))
    }

    @Test func test_medium_selected() {
      assertCoachSnapshot(of: framed(selectedState, .medium))
    }

    @Test func test_medium_rest() {
      assertCoachSnapshot(of: framed(restState, .medium))
    }

    @Test func test_medium_gate() {
      assertCoachSnapshot(of: framed(gateState, .medium))
    }

    @Test func test_medium_stale() {
      assertCoachSnapshot(of: framed(staleState, .medium))
    }

    // MARK: - accessoryInline

    @Test func test_inline_session() {
      assertCoachSnapshot(of: framed(sessionState, .inline))
    }

    @Test func test_inline_selected() {
      assertCoachSnapshot(of: framed(selectedState, .inline))
    }

    @Test func test_inline_rest() {
      assertCoachSnapshot(of: framed(restState, .inline))
    }

    @Test func test_inline_gate() {
      assertCoachSnapshot(of: framed(gateState, .inline))
    }

    @Test func test_inline_stale() {
      assertCoachSnapshot(of: framed(staleState, .inline))
    }

    // MARK: - accessoryRectangular

    @Test func test_rectangular_session() {
      assertCoachSnapshot(of: framed(sessionState, .rectangular))
    }

    @Test func test_rectangular_selected() {
      assertCoachSnapshot(of: framed(selectedState, .rectangular))
    }

    @Test func test_rectangular_rest() {
      assertCoachSnapshot(of: framed(restState, .rectangular))
    }

    @Test func test_rectangular_gate() {
      assertCoachSnapshot(of: framed(gateState, .rectangular))
    }

    @Test func test_rectangular_stale() {
      assertCoachSnapshot(of: framed(staleState, .rectangular))
    }
  }
#endif
