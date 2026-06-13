// NutritionView + YesterdayIntakeView snapshots (ARCHITECTURE D16): the composed Today nutrition area —
// the "TODAY'S FUEL" panel + COACH NOTE and the yesterday recap — for a **logged day** and the **no-food
// empty state**, in light + dark on the single reference device, via the shared `CoachTestSupport` harness.
// The whole body is `#if canImport(UIKit)`-guarded so this target compiles to an empty module on the macOS
// host (`swift test` stays green); it runs on the pinned iOS 26 simulator via `make test-snapshots`.

#if canImport(UIKit)
  import CoachTestSupport
  import DesignSystem
  import DomainModels
  import SampleData
  import SnapshotTesting
  import SwiftUI
  import Testing

  @testable import TodayFeature

  @MainActor
  struct NutritionSnapshotTests {
    /// The composed nutrition area (the `.nutrition` arm of `TodayView`'s `ready` branch): the fuel panel +
    /// COACH NOTE above the yesterday recap / empty state, framed on the page background.
    private func framed(_ brief: DomainModels.DailyBrief) -> some View {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
        NutritionView(brief: brief)
        YesterdayIntakeView(intake: brief.intakeYesterday)
      }
      .padding(CoachSpacing.spaceLg)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(Color.coachBackground)
    }

    /// The green (logged) brief augmented with a `.nutrition` narrative section so the COACH NOTE block
    /// renders — the fixtures ship no nutrition section yet (the slice would otherwise be empty).
    private func loggedBrief() -> DomainModels.DailyBrief {
      var brief = SampleData.dailyBriefGreen
      brief.narrative += [
        DomainModels.NarrativeSection(
          type: .nutrition,
          heading: "Coach note",
          body: "Protein is the daily non-negotiable — spread it across meals. "
            + "Keep carbs around today's session and let fat fill the rest."
        ),
      ]
      return brief
    }

    @Test func test_loggedDay() { assertCoachSnapshot(of: framed(loggedBrief())) }
    @Test func test_noFood() { assertCoachSnapshot(of: framed(SampleData.dailyBriefNoFood)) }
  }
#endif
