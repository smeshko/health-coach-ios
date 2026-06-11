// SessionFeatureView snapshots (ARCHITECTURE D16) — the `Row.png` card variants and the inline-swap states,
// in light + dark on the single reference device, via the shared `CoachTestSupport` harness. The whole body
// is `#if canImport(UIKit)`-guarded so this target compiles to an empty module on the macOS host (`swift
// test` stays green); it runs on the pinned iOS 26 simulator via `make test-snapshots`.
//
// Fixtures are **inline `DomainModels` literals**: the `SampleData` briefs carry ≤1 alternative, no
// alternative with a `zoneTarget`, no `.session`-typed narrative, and only forced-REST rest fixtures with
// `skipOk: true`, so they cannot drive these cases. The card is framed on `.coachBackground` to mirror the
// real screen.

#if canImport(UIKit)
  import CoachTestSupport
  import ComposableArchitecture
  import DesignSystem
  import DomainModels
  import SnapshotTesting
  import SwiftUI
  import Testing

  @testable import SessionFeature

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

    // MARK: - The Row.png variants + swap states

    /// Collapsed: primary easy run, 2 alternatives + `skipOk` (footer "♡ Skipping is fine today" + "Swap ›"),
    /// the in-card session narrative, zone bar on Z2.
    @Test func test_easyRun_collapsed() {
      assertCoachSnapshot(of: framed(SessionFeature.State(
        session: easyRun(), alternatives: [altLowImpact(), altStrength()],
        skipOk: true, narrative: sessionNarrative(), zones: zones()
      )))
    }

    /// Swap expanded — the SWAP TO header + the two alternative rows beneath the card.
    @Test func test_easyRun_swapExpanded() {
      assertCoachSnapshot(of: framed(SessionFeature.State(
        session: easyRun(), alternatives: [altLowImpact(), altStrength()],
        skipOk: true, zones: zones(), isSwapExpanded: true
      )))
    }

    /// Swap selected — SWAPPED TO header, the first row highlighted, and the card showing the **alternative**
    /// with **its** zone (Z1) highlighted/captioned (the first alternative carries a different `zoneTarget`
    /// than the primary — locks DECISIONS #4).
    @Test func test_easyRun_swapSelected() {
      assertCoachSnapshot(of: framed(SessionFeature.State(
        session: easyRun(), alternatives: [altLowImpact(), altStrength()],
        skipOk: true, zones: zones(), selectedAlternativeIndex: 0, isSwapExpanded: true
      )))
    }

    /// The rest-day card — a coach-chosen rest session, no alternatives/skip (suggestion box + recovery icon
    /// row + "Rest is training too." footer; no zone bar / numeral / swap).
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
    /// add-on chip from the `prehabFoot` flag.
    @Test func test_strength() {
      let strength = SessionBlock(
        card: .strengthFull, intensity: .quality,
        durationMinLow: 40, durationMinHigh: 50, flags: [.prehabFoot]
      )
      assertCoachSnapshot(of: framed(SessionFeature.State(session: strength, skipOk: true)))
    }

    /// An `effort_based` long run — the flag in the meta row, the HR ceiling de-emphasized (bpm line present).
    @Test func test_longRun_effortBased() {
      let longRun = SessionBlock(
        card: .longRun, intensity: .easy, zoneTarget: .z2,
        durationMinLow: 75, durationMinHigh: 90, hrCapBpm: 150, flags: [.effortBased]
      )
      assertCoachSnapshot(of: framed(SessionFeature.State(session: longRun, zones: zones())))
    }

    /// An `append_to_easy` easy run — the flag's `DisplayLabel` in the meta row, attached to the run (no
    /// invented stride count).
    @Test func test_easyRun_appendToEasy() {
      let block = SessionBlock(
        card: .easyRun, intensity: .easy, zoneTarget: .z2,
        durationMinLow: 35, durationMinHigh: 45, hrCapBpm: 146, cadenceSpm: 170, flags: [.appendToEasy]
      )
      assertCoachSnapshot(of: framed(SessionFeature.State(session: block, zones: zones())))
    }

    /// No alternatives + no skip — the collapsed footer-less layout (a PLAN risk mitigation, not optional).
    @Test func test_noAlternatives_noSkip() {
      assertCoachSnapshot(of: framed(SessionFeature.State(session: easyRun(), zones: zones())))
    }
  }
#endif
