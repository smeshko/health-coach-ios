import Foundation
import Testing

@testable import DesignSystem

struct RangeFormatterTests {
  private let enUS = Locale(identifier: "en_US")

  @Test func test_integerRange_oneUnitOneDash() {
    #expect(RangeFormatter.string(low: 65, high: 80, unit: "g") == "65–80 g")
  }

  @Test func test_integerRange_collapsesWhenEqual() {
    #expect(RangeFormatter.string(low: 70, high: 70, unit: "g") == "70 g")
  }

  @Test func test_decimalRange_oneUnitOneDash() {
    #expect(
      RangeFormatter.string(low: 2.5, high: 3.2, unit: "L", locale: enUS) ==
        "2.5–3.2 L"
    )
  }

  @Test func test_decimalRange_collapsesWhenEqual() {
    #expect(
      RangeFormatter.string(low: 3.0, high: 3.0, unit: "L", locale: enUS) ==
        "3 L"
    )
  }

  @Test func test_decimalRange_trailingZerosDrop() {
    #expect(
      RangeFormatter.string(low: 2.0, high: 2.5, unit: "L", locale: enUS) ==
        "2–2.5 L"
    )
  }
}
