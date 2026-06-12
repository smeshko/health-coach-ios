import Foundation
import Testing

@testable import DomainModels

/// Codable coverage for the in-module persistence coding added in Phase 11.2. The open enums use a
/// single-value raw-string codec over the **wire strings**; the closed enums use `String` raw values
/// equal to the wire strings. The encoded form must equal the wire string so Phase 11.3's enum
/// sharing changes no persisted shape.
struct CodableTests {
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    try decoder.decode(T.self, from: encoder.encode(value))
  }

  private func encodedString(_ value: some Encodable) throws -> String {
    try #require(String(bytes: try encoder.encode(value), encoding: .utf8))
  }

  // MARK: - Closed enums: wire raw strings

  @Test func test_closedEnum_encodesWireRawString() throws {
    #expect(try encodedString(Card.easyRun) == "\"easy_run\"")
    #expect(try encodedString(Card.boxingTechnique) == "\"boxing_technique\"")
    #expect(try encodedString(Card.threshold) == "\"threshold\"")
    #expect(try encodedString(Zone.z3) == "\"z3\"")
    #expect(try encodedString(Intensity.quality) == "\"quality\"")
    #expect(try encodedString(NarrativeType.summary) == "\"summary\"")
  }

  @Test func test_closedEnum_roundTrips() throws {
    for card in Card.allCases { try #expect(roundTrip(card) == card) }
    for zone in Zone.allCases { try #expect(roundTrip(zone) == zone) }
    for band in ReadinessBand.allCases { try #expect(roundTrip(band) == band) }
  }

  // MARK: - Open enums: single-value raw-string codec over wire strings

  @Test func test_openEnum_knownCase_encodesWireString_andRoundTrips() throws {
    #expect(try encodedString(Flag.qualityDay) == "\"quality_day\"")
    #expect(try encodedString(Flag.prehabFoot) == "\"prehab:foot\"")
    #expect(try encodedString(SafetyReason.giFlare) == "\"gi_flare\"")
    #expect(try encodedString(PenaltyFactor.sleepBelow7h) == "\"sleep_below_7h\"")
    try #expect(roundTrip(Flag.qualityDay) == .qualityDay)
    try #expect(roundTrip(SafetyReason.hrvCrash) == .hrvCrash)
    try #expect(roundTrip(PenaltyFactor.yesterdayHardDay) == .yesterdayHardDay)
  }

  @Test func test_openEnum_arbitraryString_decodesToUnknown() throws {
    #expect(try decoder.decode(Flag.self, from: Data("\"brand_new_flag\"".utf8)) == .unknown("brand_new_flag"))
    #expect(try decoder.decode(SafetyReason.self, from: Data("\"odd_signal\"".utf8)) == .unknown("odd_signal"))
    #expect(try decoder.decode(PenaltyFactor.self, from: Data("\"late_caffeine\"".utf8)) == .unknown("late_caffeine"))
    // An `.unknown` carrying a non-colliding string round-trips verbatim.
    try #expect(roundTrip(Flag.unknown("brand_new_flag")) == .unknown("brand_new_flag"))
  }

  /// D2: the codec is **normalizing, not lossless** — an `.unknown` whose raw string collides with a
  /// known case's wire string round-trips to the known case. Asserted as intended behavior; no
  /// fixture or production path produces such a value (the wire mapping only emits `.unknown` for
  /// strings that did NOT match a known case).
  @Test func test_openEnum_caseCollidingUnknown_normalizesToKnownCase() throws {
    try #expect(roundTrip(Flag.unknown("quality_day")) == .qualityDay)
    try #expect(roundTrip(SafetyReason.unknown("gi_flare")) == .giFlare)
    try #expect(roundTrip(PenaltyFactor.unknown("sleep_below_7h")) == .sleepBelow7h)
  }
}
