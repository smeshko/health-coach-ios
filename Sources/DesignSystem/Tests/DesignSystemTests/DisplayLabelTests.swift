import DomainModels
import Testing

@testable import DesignSystem

struct DisplayLabelTests {
  /// Every closed-enum case renders a non-empty human label that is NOT the raw case name.
  @Test func test_closedEnums_haveNonEmptyHumanLabels() {
    func check<T: DisplayLabel & CaseIterable>(_ type: T.Type) {
      for value in T.allCases {
        #expect(!value.label.isEmpty, "\(type) \(value) has an empty label")
        #expect(
          value.label != String(describing: value),
          "\(type) \(value) renders the raw case name"
        )
      }
    }
    check(Card.self)
    check(ReadinessBand.self)
    check(DayType.self)
    check(Intensity.self)
    check(Tier.self)
    check(Weekday.self)
  }

  @Test func test_openEnums_knownCases_haveLabels() {
    #expect(Flag.qualityDay.label == "Quality Day")

    // PenaltyFactor — the readiness "why" rows (§12.3 wording, not machine title-case).
    #expect(PenaltyFactor.sleepBelow7h.label == "Short sleep")
    #expect(PenaltyFactor.sleepBelow5h.label == "Very short sleep")
    #expect(PenaltyFactor.hrvBelowBaseline.label == "HRV below baseline")
    #expect(PenaltyFactor.rhrAboveBaseline.label == "Resting HR elevated")
    #expect(PenaltyFactor.yesterdayHardDay.label == "Hard session yesterday")

    // SafetyReason — the forced-REST reason chips (§12.3 wording).
    #expect(SafetyReason.giFlare.label == "Gut flare")
    #expect(SafetyReason.illness.label == "Feeling unwell")
    #expect(SafetyReason.kneePainHigh.label == "Knee pain high")
    #expect(SafetyReason.sleepBelow4h.label == "Very little sleep")
    #expect(SafetyReason.rhrSpike.label == "Resting HR spike")
    #expect(SafetyReason.hrvCrash.label == "HRV drop")
  }

  /// `.unknown(raw)` renders a graceful human label, never the raw key — for snake_case and camelCase.
  @Test func test_openEnums_unknown_rendersGracefulLabel() {
    #expect(Flag.unknown("custom_flag").label == "Custom Flag")
    #expect(Flag.unknown("custom_flag").label != "custom_flag")
    #expect(SafetyReason.unknown("weird_thing").label == "Weird Thing")
    #expect(PenaltyFactor.unknown("late_caffeine").label == "Late Caffeine")
    #expect(Flag.unknown("newSpecialFlag").label == "New Special Flag")
    // letter→digit boundary, both snake_case and camelCase forms.
    #expect(Flag.unknown("sleep_below_7h").label == "Sleep Below 7h")
    #expect(Flag.unknown("sleepBelow7h").label == "Sleep Below 7h")
    // empty / degenerate input never crashes or renders empty.
    #expect(Flag.unknown("").label == "Unknown")
  }

  @Test func test_errorDisplay_allCasesHaveLabels() {
    for value in ErrorDisplay.allCases {
      #expect(!value.label.isEmpty, "\(value) has an empty label")
    }
  }

  @Test func test_errorDisplay_tokenRejected_hasConnectCopy() {
    #expect(
      ErrorDisplay.tokenRejected.label ==
        "That token doesn't look right. Check it and paste again."
    )
    // Distinct from the 401 *banner* copy, which stays `.unauthorized`.
    #expect(ErrorDisplay.tokenRejected.label != ErrorDisplay.unauthorized.label)
  }

  @Test func test_colorAndIconCues_existForBandAndIntensity() {
    // Compile-proof that the surviving cues are present (color/icon are never the sole signal).
    _ = ReadinessBand.green.color
    _ = Intensity.quality.iconName
  }
}
