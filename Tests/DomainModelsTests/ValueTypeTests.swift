@testable import DomainModels
import Foundation
import XCTest

final class ValueTypeTests: XCTestCase {
  private func makeSession(card: Card = .easyRun) -> SessionBlock {
    SessionBlock(card: card, intensity: .easy, durationMinLow: 40, durationMinHigh: 55)
  }

  private func makeMacroFocus() -> MacroFocus {
    MacroFocus(
      dayType: .moderate, caloriesKcal: 2600, proteinG: 170, carbsG: 300,
      fatGLow: 60, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.5
    )
  }

  func test_dailyBrief_guaranteedArraysDefaultToEmpty() {
    let brief = DailyBrief(
      date: Date(timeIntervalSince1970: 0),
      readiness: Readiness(score: 80, band: .green),
      safetyGate: SafetyGate(triggered: false),
      session: makeSession(),
      skipOk: true,
      macroFocus: makeMacroFocus(),
      generatedAt: Date(timeIntervalSince1970: 0),
      cached: false
    )
    // Constructed without alternatives/narrative — both default to [] (never nil).
    XCTAssertEqual(brief.alternatives, [])
    XCTAssertEqual(brief.narrative, [])
    XCTAssertNil(brief.intakeYesterday)
    // Readiness/SafetyGate guaranteed arrays default empty too.
    XCTAssertEqual(brief.readiness.penalties, [])
    XCTAssertEqual(brief.safetyGate.reasons, [])
  }

  func test_sessionBlock_computedConveniences() {
    let easy = makeSession(card: .easyRun)
    XCTAssertEqual(easy.durationRange, 40 ... 55)
    XCTAssertFalse(easy.isRest)

    let rest = SessionBlock(card: .rest, intensity: .recovery, durationMinLow: 0, durationMinHigh: 0)
    XCTAssertTrue(rest.isRest)
  }
}
