// ReadinessComponentView snapshots (ARCHITECTURE D16): the readiness card across the three bands
// (**green / amber / red**, collapsed) and the **why-open** itemized breakdown (`… — Why open.png`), in
// light + dark on the single reference device, via the shared `CoachTestSupport` harness. The whole body
// is `#if canImport(UIKit)`-guarded so this target compiles to an empty module on the macOS host
// (`swift test` stays green); it runs on the pinned iOS 26 simulator via `make test-snapshots`.
//
// The tri-band meter is the merged `SegmentedBar.readiness` primitive (Phase 8.2) — there is no separate
// `ReadinessGauge` to re-record. The card is framed on `.coachBackground` to mirror the real screen.

#if canImport(UIKit)
  import CoachTestSupport
  import ComposableArchitecture
  import DesignSystem
  import DomainModels
  import SampleData
  import SnapshotTesting
  import SwiftUI
  import Testing

  @testable import TodayFeature

  @MainActor
  struct ReadinessSnapshotTests {
    /// The mapped domain brief for a canned scenario (force-try: an in-bundle fixture decode failure is a
    /// build-time authoring error).
    private func brief(_ scenario: SampleScenario) -> DomainModels.DailyBrief {
      // swiftlint:disable:next force_try
      try! SampleData.dailyBrief(scenario).domain
    }

    /// The readiness card for a scenario, summary slice attached, framed on the page background.
    private func framed(_ scenario: SampleScenario, whyExpanded: Bool = false) -> some View {
      let brief = brief(scenario)
      let store = Store(
        initialState: ReadinessComponent.State(readiness: brief.readiness, isWhyExpanded: whyExpanded)
      ) { ReadinessComponent() }
      return ReadinessComponentView(store: store, summary: brief.narrative.filter { $0.type == .summary })
        .padding(CoachSpacing.spaceLg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.coachBackground)
    }

    @Test func test_green() { assertCoachSnapshot(of: framed(.dailyBriefGreen)) }
    @Test func test_amber() { assertCoachSnapshot(of: framed(.dailyBriefAmber)) }
    @Test func test_red() { assertCoachSnapshot(of: framed(.dailyBriefRed)) }
    @Test func test_amber_whyOpen() { assertCoachSnapshot(of: framed(.dailyBriefAmber, whyExpanded: true)) }
  }
#endif
