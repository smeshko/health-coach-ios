import DesignSystem
import DomainModels
import SwiftUI

/// Snapshot fixture for the `SessionCard` composite. The workout variants, drawn from the design
/// references (`Today · Exercise.png`): an easy run (Z2 zone bar + zone-range caption + cadence line +
/// the in-card session narrative + a prehab add-on + footer slots) and a quality session (Z4 bar + an
/// hr-cap line, no zone-range caption). The rest-day + strength variants are added in TASK-006.
struct SessionCardCatalogView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
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
    .padding(CoachSpacing.spaceMd)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.coachBackground)
  }
}
