// SessionFeatureView snapshots (ARCHITECTURE D16) — the `Today · Exercise.png` carousel states (primary
// selected, an alternative selected, a lone candidate, plus the rest / strength / effort-based card types),
// in light + dark on the single reference device, via the shared `CoachTestSupport` harness. The whole body
// is `#if canImport(UIKit)`-guarded so this target compiles to an empty module on the macOS host (`swift
// test` stays green); it runs on the pinned iOS 26 simulator via `make test-snapshots`.
//
// Fixtures are **inline `DomainModels` literals**: the `SampleData` briefs carry ≤1 alternative, no
// alternative with a `zoneTarget`, no `.session`-typed narrative, and only forced-REST rest fixtures with
// `skipOk: true`, so they cannot drive these cases. The carousel is framed on `.coachBackground` to mirror
// the real screen.

#if canImport(UIKit)
  import CoachTestSupport
  import ComposableArchitecture
  import DesignSystem
  import DomainModels
  import SnapshotTesting
  import SwiftUI
  import Testing

  @testable import TodayFeature

  @MainActor
  struct SessionFeatureViewSnapshotTests {
    // MARK: - Fixtures

    /// A full five-zone bpm map so the zone bar caption resolves per displayed session.
    private func zones() -> Zones {
      Zones(
        z1: ZoneRange(low: 100, high: 120),
        z2: ZoneRange(low: 120, high: 140),
        z3: ZoneRange(low: 140, high: 155),
        z4: ZoneRange(low: 155, high: 168),
        z5: ZoneRange(low: 168, high: 180)
      )
    }

    /// The primary recommended easy Z2 run (bpm/cadence line present).
    private func easyRun() -> SessionBlock {
      SessionBlock(
        card: .easyRun, intensity: .easy, zoneTarget: .z2,
        durationMinLow: 35, durationMinHigh: 45, hrCapBpm: 146, cadenceSpm: 170
      )
    }

    /// First alternative — a lower-impact steady-cardio block in a **different** zone (Z1) than the primary,
    /// so a swap to it re-resolves the zone bar/caption to Z1 (DECISIONS #4).
    private func altLowImpact() -> SessionBlock {
      SessionBlock(
        card: .steadyCardio, intensity: .easy, zoneTarget: .z1,
        durationMinLow: 40, durationMinHigh: 40, flags: [.lowImpact]
      )
    }

    /// Second alternative — a no-zone strength block (renders the effort scale, not a zone bar).
    private func altStrength() -> SessionBlock {
      SessionBlock(card: .strengthFull, intensity: .quality, durationMinLow: 30, durationMinHigh: 30)
    }

    /// The "how to run it" `.session` narrative slice the parent passes for the in-card slot.
    private func sessionNarrative() -> [NarrativeSection] {
      [NarrativeSection(
        type: .session, heading: "",
        body: "Keep it conversational — you should be able to talk in full sentences the whole way."
      )]
    }

    /// Build the framed `SessionFeatureView` for a state (store + page-background chrome).
    private func framed(_ state: SessionFeature.State) -> some View {
      let store = Store(initialState: state) { SessionFeature() }
      return SessionFeatureView(store: store)
        .padding(CoachSpacing.spaceLg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.coachBackground)
    }

    // MARK: - Carousel states

    /// Primary selected (default): an easy Z2 run + 2 alternatives + `skipOk`, the in-card session narrative,
    /// zone bar on Z2. Card 0 carries the green outline + "Suggested" eyebrow; the next card peeks on the
    /// trailing edge; the pager dots sit beneath (first dot active).
    @Test func test_carousel_primarySelected() {
      assertCoachSnapshot(of: framed(SessionFeature.State(
        session: easyRun(), alternatives: [altLowImpact(), altStrength()],
        skipOk: true, narrative: sessionNarrative(), zones: zones()
      )))
    }

    /// An alternative committed (`selectedIndex: 1`): selection and scroll are **decoupled** (DECISIONS D1) —
    /// the committed card (candidate 1) carries the green outline while the pager dots advance to position 1.
    /// (A static snapshot renders the leading card; the seeded `scrollPosition` only physically scrolls to the
    /// pick at runtime, so here candidate 1 appears outlined as the peeking neighbour.)
    @Test func test_carousel_alternativeSelected() {
      assertCoachSnapshot(of: framed(SessionFeature.State(
        session: easyRun(), alternatives: [altLowImpact(), altStrength()],
        skipOk: true, narrative: sessionNarrative(), zones: zones(), selectedIndex: 1
      )))
    }

    /// A lone candidate — one full-width card, **no** pager dots and **no** role eyebrow (RESEARCH
    /// resolution); the green outline still marks it as today's pick.
    @Test func test_carousel_singleCandidate() {
      assertCoachSnapshot(of: framed(SessionFeature.State(
        session: easyRun(), skipOk: true, narrative: sessionNarrative(), zones: zones()
      )))
    }

    /// The rest-day card — a coach-chosen rest session, lone candidate (suggestion box + recovery icon row +
    /// "Rest is training too." footer; no zone bar / numeral / eyebrow / dots).
    @Test func test_restDay() {
      let rest = SessionBlock(card: .rest, intensity: .recovery, durationMinLow: 0, durationMinHigh: 0)
      assertCoachSnapshot(of: framed(SessionFeature.State(
        session: rest,
        narrative: [NarrativeSection(
          type: .session, heading: "",
          body: "Your body did the work — today it adapts. Nothing to prove."
        )]
      )))
    }

    /// A strength session — the 1–10 effort scale with the derived band (quality → high band) and a prehab
    /// add-on chip from the `prehabFoot` flag. Lone candidate.
    @Test func test_strength() {
      let strength = SessionBlock(
        card: .strengthFull, intensity: .quality,
        durationMinLow: 40, durationMinHigh: 50, flags: [.prehabFoot]
      )
      assertCoachSnapshot(of: framed(SessionFeature.State(session: strength, skipOk: true)))
    }

    /// An `effort_based` long run — the flag in the meta row, the HR ceiling de-emphasized (bpm line
    /// present). Lone candidate.
    @Test func test_longRun_effortBased() {
      let longRun = SessionBlock(
        card: .longRun, intensity: .easy, zoneTarget: .z2,
        durationMinLow: 75, durationMinHigh: 90, hrCapBpm: 150, flags: [.effortBased]
      )
      assertCoachSnapshot(of: framed(SessionFeature.State(session: longRun, zones: zones())))
    }
  }
#endif
