import DomainModels
import XCTest

@testable import DesignSystem

final class DisplayLabelTests: XCTestCase {
  /// Every closed-enum case renders a non-empty human label that is NOT the raw case name.
  func test_closedEnums_haveNonEmptyHumanLabels() {
    func check<T: DisplayLabel & CaseIterable>(_ type: T.Type) {
      for value in T.allCases {
        XCTAssertFalse(value.label.isEmpty, "\(type) \(value) has an empty label")
        XCTAssertNotEqual(
          value.label, String(describing: value),
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

  func test_openEnums_knownCases_haveLabels() {
    XCTAssertEqual(Flag.qualityDay.label, "Quality Day")
    XCTAssertEqual(SafetyReason.giFlare.label, "GI Flare")
    XCTAssertEqual(PenaltyFactor.sleepBelow7h.label, "Sleep Below 7h")
  }

  /// `.unknown(raw)` renders a graceful human label, never the raw key — for snake_case and camelCase.
  func test_openEnums_unknown_rendersGracefulLabel() {
    XCTAssertEqual(Flag.unknown("custom_flag").label, "Custom Flag")
    XCTAssertNotEqual(Flag.unknown("custom_flag").label, "custom_flag")
    XCTAssertEqual(SafetyReason.unknown("weird_thing").label, "Weird Thing")
    XCTAssertEqual(PenaltyFactor.unknown("late_caffeine").label, "Late Caffeine")
    XCTAssertEqual(Flag.unknown("newSpecialFlag").label, "New Special Flag")
    // letter→digit boundary, both snake_case and camelCase forms.
    XCTAssertEqual(Flag.unknown("sleep_below_7h").label, "Sleep Below 7h")
    XCTAssertEqual(Flag.unknown("sleepBelow7h").label, "Sleep Below 7h")
    // empty / degenerate input never crashes or renders empty.
    XCTAssertEqual(Flag.unknown("").label, "Unknown")
  }

  func test_errorDisplay_allCasesHaveLabels() {
    for value in ErrorDisplay.allCases {
      XCTAssertFalse(value.label.isEmpty, "\(value) has an empty label")
    }
  }

  func test_errorDisplay_tokenRejected_hasConnectCopy() {
    XCTAssertEqual(
      ErrorDisplay.tokenRejected.label,
      "That token doesn't look right. Check it and paste again."
    )
    // Distinct from the 401 *banner* copy, which stays `.unauthorized`.
    XCTAssertNotEqual(ErrorDisplay.tokenRejected.label, ErrorDisplay.unauthorized.label)
  }

  func test_colorCues_existForBandZoneIntensity() {
    // Compile-proof that the color cue is paired with each band/zone/intensity (color is never sole).
    _ = ReadinessBand.green.color
    _ = ReadinessBand.green.iconName
    _ = Zone.z3.color
    _ = Intensity.quality.color
    _ = Intensity.quality.iconName
  }
}
