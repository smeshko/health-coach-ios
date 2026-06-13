import Foundation
import Testing

@testable import DomainModels

struct ValueTypeTests {
  private func makeSession(card: Card = .easyRun) -> SessionBlock {
    SessionBlock(card: card, intensity: .easy, durationMinLow: 40, durationMinHigh: 55)
  }

  @Test func test_sessionBlock_computedConveniences() {
    let easy = makeSession(card: .easyRun)
    #expect(easy.durationRange == 40 ... 55)
    #expect(!easy.isRest)

    let rest = SessionBlock(card: .rest, intensity: .recovery, durationMinLow: 0, durationMinHigh: 0)
    #expect(rest.isRest)
  }

  /// Audit gap #12 / production finding 3: an inverted server brief (`durationMinLow >
  /// durationMinHigh`) must NOT trap on the `ClosedRange` precondition at render time — the guard
  /// clamps to `min ... max` so a malformed brief renders instead of crashing.
  @Test func test_durationRange_invertedBounds_clampsInsteadOfTrapping() {
    let inverted = SessionBlock(card: .easyRun, intensity: .easy, durationMinLow: 55, durationMinHigh: 40)
    #expect(inverted.durationRange == 40 ... 55, "inverted bounds clamp to a valid min...max window")
  }
}
