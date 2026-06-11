import DesignSystem
import DomainModels
import SwiftUI

/// Composite gallery page — the `SessionCard` variants: an easy run + a quality session
/// (`Today · Exercise.png`), a strength session with the 1–10 effort scale
/// (`Strength · Duration-led.png`), and a rest day (`Cell.png`).
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

      stateLabel("Strength (effort scale)")
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

      stateLabel("Rest day")
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
