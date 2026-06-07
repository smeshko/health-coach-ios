@testable import DomainModels
import XCTest

final class EnumTests: XCTestCase {
  func test_semanticEnum_unknownCarriesAssociatedValue() {
    XCTAssertEqual(Flag.unknown("brand_new_flag"), Flag.unknown("brand_new_flag"))
    XCTAssertNotEqual(Flag.unknown("a"), Flag.unknown("b"))
    XCTAssertNotEqual(Flag.unknown("impact"), Flag.impact)

    XCTAssertEqual(SafetyReason.unknown("x"), SafetyReason.unknown("x"))
    XCTAssertNotEqual(SafetyReason.unknown("x"), SafetyReason.unknown("y"))

    XCTAssertEqual(PenaltyFactor.unknown("x"), PenaltyFactor.unknown("x"))
    XCTAssertNotEqual(PenaltyFactor.unknown("x"), PenaltyFactor.unknown("y"))
  }

  func test_closedEnums_haveExpectedCaseCounts() {
    XCTAssertEqual(Card.allCases.count, 20)
    XCTAssertEqual(Zone.allCases.count, 5)
    XCTAssertEqual(ReadinessBand.allCases.count, 3)
    XCTAssertEqual(DayType.allCases.count, 3)
    XCTAssertEqual(Intensity.allCases.count, 3)
    XCTAssertEqual(NarrativeType.allCases.count, 5)
    XCTAssertEqual(Tier.allCases.count, 2)
    XCTAssertEqual(Weekday.allCases.count, 7)
  }
}
