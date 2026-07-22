import Foundation
import Testing

@testable import DomainModels

/// The parity guard for the open-enum wire-string maps (Phase 20.1, DECISIONS D1/D2).
///
/// Each open enum owns exactly one wire-string map: the exhaustive `wireString` switch
/// (compiler-enforced) plus `knownCases` (the decode dictionary is derived from it). These tests
/// fail if the two ever disagree for a known case — a case added to one side only cannot silently
/// diverge again. Residual risk (D2): a case omitted from `knownCases` entirely is invisible here;
/// it surfaces as a loud functional failure (its wire string never decodes) in the fixture-driven
/// mapping tests.
private protocol WireStringMapped: Codable, Hashable {
  init(wireString: String)
  var wireString: String { get }
  static var knownCases: [Self] { get }
  static func unknown(_ raw: String) -> Self
}

extension Flag: WireStringMapped {}
extension SafetyReason: WireStringMapped {}
extension PenaltyFactor: WireStringMapped {}

struct WireStringParityTests {
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  private func assertParity<T: WireStringMapped>(_ type: T.Type) throws {
    // (1) Decode/encode agreement: a case present in encode but missing in decode fails here.
    for knownCase in T.knownCases {
      #expect(T(wireString: knownCase.wireString) == knownCase)
    }
    // (2) JSON Codable round-trip for every known case.
    for knownCase in T.knownCases {
      let decoded = try decoder.decode(T.self, from: encoder.encode(knownCase))
      #expect(decoded == knownCase)
    }
    // (3) Wire strings pairwise distinct — two cases claiming one string collapse the set.
    #expect(Set(T.knownCases.map(\.wireString)).count == T.knownCases.count)
    // (4) `.unknown` survives verbatim through `init(wireString:)` and `Codable`.
    #expect(T(wireString: "never_seen_xyz") == T.unknown("never_seen_xyz"))
    let unknownRoundTrip = try decoder.decode(T.self, from: encoder.encode(T.unknown("never_seen_xyz")))
    #expect(unknownRoundTrip == T.unknown("never_seen_xyz"))
  }

  @Test func test_flag_wireStringMapParity() throws {
    try assertParity(Flag.self)
  }

  @Test func test_safetyReason_wireStringMapParity() throws {
    try assertParity(SafetyReason.self)
  }

  @Test func test_penaltyFactor_wireStringMapParity() throws {
    try assertParity(PenaltyFactor.self)
  }
}
