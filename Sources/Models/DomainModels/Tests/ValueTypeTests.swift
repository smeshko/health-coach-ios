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

  /// Phase 20.1 D5: `DayTypePatternEntry.weekday` is THE reading of the free `suggestedDay` wire
  /// string — case-insensitive, so a case-mismatched entry ("Tue"/"TUE") resolves to its day instead
  /// of silently falling through to the rest-day cut; unrecognised strings stay `nil`.
  @Test func test_dayTypePatternEntry_weekday_normalizesCase() {
    func entry(_ day: String) -> DayTypePatternEntry {
      DayTypePatternEntry(suggestedDay: day, dayType: .moderate, caloriesKcal: 2600, carbsG: 300)
    }
    #expect(entry("tue").weekday == .tue)
    #expect(entry("Tue").weekday == .tue)
    #expect(entry("TUE").weekday == .tue)
    #expect(entry("notaday").weekday == nil)
    #expect(entry("").weekday == nil)
    // The stored string stays verbatim — interpretation-on-read, not coercion.
    #expect(entry("Tue").suggestedDay == "Tue")
  }
}
