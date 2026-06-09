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
    check(Zone.self)
    check(ReadinessBand.self)
    check(DayType.self)
    check(Intensity.self)
    check(NarrativeType.self)
    check(Tier.self)
    check(Weekday.self)
  }

  @Test func test_openEnums_knownCases_haveLabels() {
    #expect(Flag.qualityDay.label == "Quality Day")
    #expect(SafetyReason.giFlare.label == "GI Flare")
    #expect(PenaltyFactor.sleepBelow7h.label == "Sleep Below 7h")
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

  @Test func test_colorCues_existForBandZoneIntensity() {
    // Compile-proof that the color cue is paired with each band/zone/intensity (color is never sole).
    _ = ReadinessBand.green.color
    _ = ReadinessBand.green.iconName
    _ = Zone.z3.color
    _ = Intensity.quality.color
    _ = Intensity.quality.iconName
  }
}
