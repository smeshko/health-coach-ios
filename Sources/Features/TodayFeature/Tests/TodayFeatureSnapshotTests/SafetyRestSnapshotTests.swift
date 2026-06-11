// SafetyRestView snapshots (ARCHITECTURE D16): the calm **forced-REST screen** for representative reasons
// (gi_flare / illness / knee) — the mapped §7.4.2 reason callout + the read-only override session, **no
// swap/skip/alternatives** — and a **coach-easy contrast** (the untripped `.normal` amber session, with
// swap/skip + an alternatives hint) proving the two states render visibly differently. Light + dark on the
// single reference device via the shared `CoachTestSupport` harness; `#if canImport(UIKit)`-guarded so the
// target compiles to an empty module on the host. Runs on the pinned iOS 26 simulator.
//
// The load-bearing distinct-states proof is the `SafetyRestComponentTests` reducer assertion
// (`from(forcedRestBrief)` ⇒ `.forcedRest` vs `from(coachEasyBrief)` ⇒ `.normal`); this contrast is the
// supplementary visual evidence. The `.normal` arm here is a thin stand-in until Phase 8.4's
// `SessionFeature` view merges (the real swap interaction lands there).

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
  struct SafetyRestSnapshotTests {
    /// The mapped domain brief for a canned scenario (force-try: an in-bundle fixture decode failure is a
    /// build-time authoring error).
    private func brief(_ scenario: SampleScenario) -> DomainModels.DailyBrief {
      // swiftlint:disable:next force_try
      try! SampleData.dailyBrief(scenario).domain
    }

    /// A view framed on the page background (mirrors the real screen chrome).
    private func framed(_ view: some View) -> some View {
      view
        .padding(CoachSpacing.spaceLg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.coachBackground)
    }

    /// The forced-REST screen for a tripped-gate scenario: the calm reason callout + the read-only
    /// override session (rest card). No swap/skip/alternatives are wired.
    private func forcedRest(_ scenario: SampleScenario) -> some View {
      let brief = brief(scenario)
      let store = Store(
        initialState: SafetyRestComponent.State(gate: brief.safetyGate, overrideSession: brief.session)
      ) { SafetyRestComponent() }
      return framed(
        SafetyRestView(
          store: store,
          narrative: brief.narrative.filter { $0.type == .session || $0.type == .caution }
        )
      )
    }

    @Test func test_forcedRest_giFlare() { assertCoachSnapshot(of: forcedRest(.dailyBriefRestGIFlare)) }
    @Test func test_forcedRest_illness() { assertCoachSnapshot(of: forcedRest(.dailyBriefRestIllness)) }
    @Test func test_forcedRest_knee() { assertCoachSnapshot(of: forcedRest(.dailyBriefRestKnee)) }

    /// The coach-easy contrast — the untripped `.normal` amber session with swap/skip affordances + an
    /// alternatives hint, visibly distinct from the forced-REST screen (which has none). A thin stand-in
    /// for Phase 8.4's `SessionFeature` view.
    @Test func test_coachEasy_contrast() {
      let brief = brief(.dailyBriefAmber)
      let view = VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
        SessionCard(
          brief.session,
          zoneRange: SampleData.sampleProfile.zones.z2,
          narrative: brief.narrative.filter { $0.type == .session || $0.type == .caution },
          onSwap: {},
          onSkip: brief.skipOk ? {} : nil
        )
        // TODO(8.4): the real SessionFeature renders the inline SWAP-TO list; the stand-in shows the count.
        if !brief.alternatives.isEmpty {
          let count = brief.alternatives.count
          Text("\(count) alternative\(count == 1 ? "" : "s") · Swap to change")
            .font(.coachTextSm)
            .foregroundStyle(.coachForegroundMuted)
        }
      }
      assertCoachSnapshot(of: framed(view))
    }
  }
#endif
