import Testing

@testable import DomainModels

struct EnumTests {
  @Test func test_semanticEnum_unknownCarriesAssociatedValue() {
    #expect(Flag.unknown("brand_new_flag") == Flag.unknown("brand_new_flag"))
    #expect(Flag.unknown("a") != Flag.unknown("b"))
    #expect(Flag.unknown("impact") != Flag.impact)

    #expect(SafetyReason.unknown("x") == SafetyReason.unknown("x"))
    #expect(SafetyReason.unknown("x") != SafetyReason.unknown("y"))

    #expect(PenaltyFactor.unknown("x") == PenaltyFactor.unknown("x"))
    #expect(PenaltyFactor.unknown("x") != PenaltyFactor.unknown("y"))
  }

  @Test func test_closedEnums_haveExpectedCaseCounts() {
    #expect(Card.allCases.count == 20)
    #expect(Zone.allCases.count == 5)
    #expect(ReadinessBand.allCases.count == 3)
    #expect(DayType.allCases.count == 3)
    #expect(Intensity.allCases.count == 3)
    #expect(NarrativeType.allCases.count == 5)
    #expect(Tier.allCases.count == 2)
    #expect(Weekday.allCases.count == 7)
  }
}
