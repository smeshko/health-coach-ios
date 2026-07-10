import ComposableArchitecture
import DomainModels
import Foundation
import SampleData
import Testing

@testable import TodayFeature

/// `TodaySessionMode` detection + `SafetyRestView` derivation tests (ARCHITECTURE D18). This is the
/// **primary** distinct-states proof (PRD §8 / §1 principle #6): a tripped gate resolves to `.forcedRest`
/// (override session = `brief.session`, empty `alternatives`) and an untripped easy day to `.normal`, so
/// the two never collapse. Also covers the §7.4.2 calm-copy switch per case + the `.unknown`/empty-reasons
/// graceful fallback. `SafetyRestView` is render-only (a plain value-init view, no reducer), so the
/// `reasonHeadlines` assertions drive its static derivation helper directly.
@MainActor
struct SafetyRestComponentTests {
  /// The mapped domain brief for a canned scenario (force-try: an in-bundle fixture decode failure is a
  /// build-time authoring error).
  private func brief(_ scenario: SampleScenario) throws -> DomainModels.DailyBrief {
    try SampleData.dailyBrief(scenario).domain
  }

  // MARK: - Distinct-states detection (the load-bearing proof)

  /// A tripped gate resolves to `.forcedRest` (override = `brief.session`, empty alternatives by
  /// contract), and **all three** forced-REST fixtures (gi_flare / illness / knee) do so identically.
  @Test func test_forcedRest_detectedFromTriggeredGate() throws {
    let brief = try brief(.dailyBriefRestGIFlare)
    #expect(brief.safetyGate.triggered)
    #expect(brief.alternatives.isEmpty) // a tripped gate carries empty alternatives by contract
    #expect(TodaySessionMode.from(brief) == .forcedRest(gate: brief.safetyGate, override: brief.session))

    for scenario in [SampleScenario.dailyBriefRestGIFlare, .dailyBriefRestIllness, .dailyBriefRestKnee] {
      let restBrief = try self.brief(scenario)
      #expect(
        TodaySessionMode.from(restBrief)
          == .forcedRest(gate: restBrief.safetyGate, override: restBrief.session)
      )
    }
  }

  @Test func test_coachEasy_untrippedGate_isNormal() throws {
    let brief = try brief(.dailyBriefAmber)
    #expect(!brief.safetyGate.triggered)
    #expect(!brief.alternatives.isEmpty) // a coach-easy day keeps real alternatives
    #expect(TodaySessionMode.from(brief) == .normal(brief.session))
  }

  // MARK: - Calm reason copy (§7.4.2, per case)

  /// Each known reason maps to its §7.4.2 calm line; an `.unknown` reason falls back to the generic line.
  @Test func test_calmCopy_perKnownReason() {
    #expect(SafetyReasonCopy.calmCopy(for: .giFlare) == "Your gut needs a break today.")
    #expect(SafetyReasonCopy.calmCopy(for: .illness) == "You flagged feeling unwell — recover first.")
    #expect(SafetyReasonCopy.calmCopy(for: .kneePainHigh) == "Knee pain is high — no running or jumping today.")
    #expect(SafetyReasonCopy.calmCopy(for: .sleepBelow4h) == "Very little sleep — today is for recovery.")
    #expect(SafetyReasonCopy.calmCopy(for: .rhrSpike) == "Your resting heart rate spiked — back off today.")
    #expect(SafetyReasonCopy.calmCopy(for: .hrvCrash) == "Your HRV dropped sharply — recover today.")
    #expect(SafetyReasonCopy.calmCopy(for: .unknown("foo")) == "Today is for recovery.")
  }

  // MARK: - reasonHeadlines (SafetyRestView's render-only derivation)

  /// `SafetyRestView.reasonHeadlines(for:)` maps a tripped gate's reasons through the calm-copy switch, and
  /// a tripped gate with **empty** `reasons` still yields a non-blank, non-raw headline (the generic line).
  @Test func test_reasonHeadlines_mapsGateReasons() throws {
    let brief = try brief(.dailyBriefRestGIFlare)
    #expect(SafetyRestView.reasonHeadlines(for: brief.safetyGate) == ["Your gut needs a break today."])

    let emptyGate = DomainModels.SafetyGate(triggered: true, reasons: [], overrideTo: .rest)
    #expect(SafetyRestView.reasonHeadlines(for: emptyGate) == ["Today is for recovery."])
  }

  // MARK: - overrideZoneRange (the forced-REST override card's zone chip, Phase 19.3)

  /// The five-zone bpm map for the chip-derivation cases below (distinct per-zone values so a wrong-zone
  /// resolution can't pass by accident).
  private let zones = DomainModels.Zones(
    z1: DomainModels.ZoneRange(low: 98, high: 118),
    z2: DomainModels.ZoneRange(low: 119, high: 132),
    z3: DomainModels.ZoneRange(low: 133, high: 147),
    z4: DomainModels.ZoneRange(low: 148, high: 160),
    z5: DomainModels.ZoneRange(low: 161, high: 178)
  )

  /// An `active_recovery` override with a `zoneTarget` resolves its bpm chip from the loaded zones. No
  /// fixture carries a triggered gate + `activeRecovery` + `zoneTarget` (the tripped fixtures are
  /// `card: rest` without one, and `daily_brief_red` has `triggered: false`), so the tripped shape is
  /// hand-rolled: `SafetyGate(triggered: true, overrideTo: .activeRecovery)`'s expanded override block.
  @Test func test_overrideZoneRange_activeRecoveryResolvesFromZones() {
    let gate = DomainModels.SafetyGate(triggered: true, reasons: [.illness], overrideTo: .activeRecovery)
    #expect(gate.triggered) // the shape the forcedRest branch receives
    let overrideBlock = DomainModels.SessionBlock(
      card: .activeRecovery,
      intensity: .recovery,
      zoneTarget: .z1,
      durationMinLow: 20,
      durationMinHigh: 30
    )
    #expect(
      TodaySessionMode.overrideZoneRange(override: overrideBlock, zones: zones)
        == DomainModels.ZoneRange(low: 98, high: 118)
    )
  }

  /// Zones not loaded (fetch failed or pending) → `nil` chip, never a crash — the same silent degrade as
  /// the normal session card.
  @Test func test_overrideZoneRange_nilZonesDegradesToNil() {
    let overrideBlock = DomainModels.SessionBlock(
      card: .activeRecovery,
      intensity: .recovery,
      zoneTarget: .z1,
      durationMinLow: 20,
      durationMinHigh: 30
    )
    #expect(TodaySessionMode.overrideZoneRange(override: overrideBlock, zones: nil) == nil)
  }

  /// `rest`/`mobility` overrides carry no `zoneTarget` → no chip (unchanged behavior), even with zones
  /// loaded.
  @Test func test_overrideZoneRange_noZoneTargetYieldsNil() {
    for card in [DomainModels.Card.rest, .mobility] {
      let overrideBlock = DomainModels.SessionBlock(
        card: card,
        intensity: .recovery,
        zoneTarget: nil,
        durationMinLow: 0,
        durationMinHigh: 0
      )
      #expect(TodaySessionMode.overrideZoneRange(override: overrideBlock, zones: zones) == nil)
    }
  }
}
