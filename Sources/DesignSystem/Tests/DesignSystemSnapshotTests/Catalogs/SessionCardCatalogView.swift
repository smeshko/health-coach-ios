import DesignSystem
import DomainModels
import SwiftUI

/// Snapshot fixture for the `SessionCard` **cardio** variants (`Today · Exercise.png`): an easy run
/// (Z2 zone bar + zone-range caption + cadence line + the in-card session narrative + a prehab add-on +
/// footer slots) and a quality session (Z4 bar + an hr-cap line, no zone-range caption). The strength +
/// rest variants are tall, so each gets its own device-fitting fixture below.
struct SessionCardCatalogView: View {
  var body: some View {
    sessionCardCatalogColumn {
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
  }
}

/// The **strength / effort-scale** variant (`Strength · Duration-led.png`): the duration numeral + the
/// 1–10 `SegmentedBar.range` effort scale with the derived band, the narrative, the flags, and a prehab
/// add-on. Only model-backed data (no fabricated RPE/reserve/rest/lift copy).
struct SessionCardStrengthCatalogView: View {
  var body: some View {
    sessionCardCatalogColumn {
      SessionCard(
        SessionBlock(
          card: .strengthLower,
          intensity: .quality,
          durationMinLow: 45,
          durationMinHigh: 45,
          flags: [.qualityDay, .prehabGlute]
        ),
        narrative: [
          NarrativeSection(
            type: .session,
            heading: "",
            body: "Leave a couple reps in the tank on every set — we're building, not testing. Add "
              + "load only when all sets feel clean."
          ),
        ],
        onSwap: {},
        onSkip: {}
      )
    }
  }
}

/// The **rest-day** variant (`Cell.png`): the narrative, the authored optional-activity suggestion box,
/// the "To help recovery along" recovery row, and the "Rest is training too." footer (no swap).
struct SessionCardRestCatalogView: View {
  var body: some View {
    sessionCardCatalogColumn {
      SessionCard(
        SessionBlock(
          card: .rest,
          intensity: .recovery,
          durationMinLow: 0,
          durationMinHigh: 0
        ),
        narrative: [
          NarrativeSection(
            type: .session,
            heading: "",
            body: "Nothing to chase today. Let the week's work settle in — this is when your body "
              + "actually adapts and gets stronger."
          ),
        ]
      )
    }
  }
}

/// Shared column scaffold — the card(s) on the app background with standard padding.
@ViewBuilder
private func sessionCardCatalogColumn(@ViewBuilder _ content: () -> some View) -> some View {
  VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
    content()
  }
  .padding(CoachSpacing.spaceMd)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  .background(.coachBackground)
}
