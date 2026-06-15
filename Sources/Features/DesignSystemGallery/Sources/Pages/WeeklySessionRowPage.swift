import DesignSystem
import DomainModels
import SwiftUI

/// Composite gallery page — the compact, inert `WeeklySessionRow` (the 2026-06-10 "This Week · Exercise"
/// design). Two device-fitting sections: the **core** rows (a cardio run with the Z1–Z5 bar + a strength
/// session on the derived effort scale, both HARD), then the **extras / edge** rows (an outlined easy
/// extra, a nil-`suggestedDay` row with no day chip, and a nil-durations row).
struct WeeklySessionRowPage: View {
  var body: some View {
    GalleryScaffold(title: "WeeklySessionRow") {
      stateLabel("Core · cardio (zone bar) + strength (effort scale) · HARD")
      WeeklySessionRowCoreSection()
      stateLabel("Extras (outlined) · EASY · nil day · nil durations")
      WeeklySessionRowExtrasSection()
    }
  }
}

/// The **core** rows: a Z4 threshold run (zone bar + bpm + solid terracotta TUE chip + HARD badge) and a
/// strength session (derived 1–10 effort scale, no zone, solid terracotta WED chip + HARD badge).
struct WeeklySessionRowCoreSection: View {
  var body: some View {
    weeklyRowSectionColumn {
      WeeklySessionRow(
        session: PlannedSession(
          card: .threshold, tier: .core, intensity: .quality, isHardDay: true,
          suggestedDay: .tue, zoneTarget: .z4, durationMinLow: 35, durationMinHigh: 45
        ),
        zoneRange: ZoneRange(low: 156, high: 168)
      )
      WeeklySessionRow(
        session: PlannedSession(
          card: .strengthLower, tier: .core, intensity: .quality, isHardDay: true,
          suggestedDay: .wed, durationMinLow: 40, durationMinHigh: 50
        ),
        zoneRange: nil
      )
    }
  }
}

/// The **extras / edge** rows: an outlined teal easy run (Z2 bar, EASY badge), a **degraded cardio** row
/// (a Z3 target but no resolved `zoneRange` — the zone target still shows, no bpm), a nil-`suggestedDay`
/// recovery row (no day chip), and a strength extra with no durations (no duration chip).
struct WeeklySessionRowExtrasSection: View {
  var body: some View {
    weeklyRowSectionColumn {
      WeeklySessionRow(
        session: PlannedSession(
          card: .easyRun, tier: .extra, intensity: .easy, isHardDay: false,
          suggestedDay: .thu, zoneTarget: .z2, durationMinLow: 30, durationMinHigh: 40
        ),
        zoneRange: ZoneRange(low: 120, high: 138)
      )
      WeeklySessionRow(
        session: PlannedSession(
          card: .steadyCardio, tier: .extra, intensity: .easy, isHardDay: false,
          suggestedDay: .sun, zoneTarget: .z3, durationMinLow: 40, durationMinHigh: 50
        ),
        zoneRange: nil // degraded: zone target shows, bpm omitted
      )
      WeeklySessionRow(
        session: PlannedSession(
          card: .mobility, tier: .extra, intensity: .recovery, isHardDay: false,
          suggestedDay: nil, durationMinLow: 20, durationMinHigh: 20
        ),
        zoneRange: nil
      )
      WeeklySessionRow(
        session: PlannedSession(
          card: .strengthPush, tier: .extra, intensity: .recovery, isHardDay: false,
          suggestedDay: .fri
        ),
        zoneRange: nil
      )
    }
  }
}

/// Shared column scaffold — the rows on the app background with standard padding. A device-fitting,
/// non-scrolling container so each section can be snapshotted whole.
@ViewBuilder
private func weeklyRowSectionColumn(@ViewBuilder _ content: () -> some View) -> some View {
  VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
    content()
  }
  .padding(CoachSpacing.spaceMd)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  .background(.coachBackground)
}
