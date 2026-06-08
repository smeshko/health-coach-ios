import XCTest

@testable import DesignSystem

final class RangeFormatterTests: XCTestCase {
  private let enUS = Locale(identifier: "en_US")

  func test_integerRange_oneUnitOneDash() {
    XCTAssertEqual(RangeFormatter.string(low: 65, high: 80, unit: "g"), "65–80 g")
  }

  func test_integerRange_collapsesWhenEqual() {
    XCTAssertEqual(RangeFormatter.string(low: 70, high: 70, unit: "g"), "70 g")
  }

  func test_decimalRange_oneUnitOneDash() {
    XCTAssertEqual(
      RangeFormatter.string(low: 2.5, high: 3.2, unit: "L", locale: enUS),
      "2.5–3.2 L"
    )
  }

  func test_decimalRange_collapsesWhenEqual() {
    XCTAssertEqual(
      RangeFormatter.string(low: 3.0, high: 3.0, unit: "L", locale: enUS),
      "3 L"
    )
  }

  func test_decimalRange_trailingZerosDrop() {
    XCTAssertEqual(
      RangeFormatter.string(low: 2.0, high: 2.5, unit: "L", locale: enUS),
      "2–2.5 L"
    )
  }
}
