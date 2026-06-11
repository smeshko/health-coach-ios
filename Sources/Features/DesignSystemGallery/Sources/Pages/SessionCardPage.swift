import DesignSystem
import DomainModels
import SwiftUI

/// Composite gallery page — the `SessionCard` workout variants (`Today · Exercise.png`): an easy run
/// (Z2 zone bar + zone-range caption + cadence line + in-card narrative + prehab add-on + footer slots)
/// and a quality session (Z4 bar + hr-cap line). The rest-day + strength variants land in TASK-006.
struct SessionCardPage: View {
  var body: some View {
    GalleryScaffold(title: "SessionCard") {
      stateLabel("Easy run (cardio)")
      SessionCard(
        SessionBlock(
          card: .easyRun,
          intensity: .easy,
          zoneTarget: .z2,
          durationMinLow: 35,
          durationMinHigh: 45,
          cadenceSpm: 170,
          flags: [.lowImpact, .prehabFoot]
        ),
        zoneRange: ZoneRange(low: 132, high: 146),
        narrative: [
          NarrativeSection(
            type: .session,
            heading: "",
            body: "Keep it honestly easy — slow is the point. Walk the hills, breathe through your "
              + "nose, and finish with a few relaxed strides."
          ),
        ],
        onSwap: {},
        onSkip: {}
      )

      stateLabel("Quality session (cardio)")
      SessionCard(
        SessionBlock(
          card: .threshold,
          intensity: .quality,
          zoneTarget: .z4,
          durationMinLow: 30,
          durationMinHigh: 40,
          hrCapBpm: 176,
          flags: [.qualityDay, .effortBased]
        ),
        narrative: [
          NarrativeSection(
            type: .session,
            heading: "",
            body: "Settle into a controlled, comfortably-hard effort — strong but repeatable, not a "
              + "race. Back off if your form starts to slip."
          ),
        ],
        onSwap: {},
        onSkip: {}
      )
    }
  }
}
