import DomainModels
import Foundation
import Testing

@testable import SessionFeature

/// Placeholder TASK-001 compile-level coverage — proves the new target + `State` + `displayedSession`
/// derivation exist (relying on `SessionBlock: Equatable`). The exhaustive `TestStore` suite replaces this
/// in TASK-002.
@MainActor
struct SessionFeatureTests {
  @Test func test_displayedSession_defaultsToPrimary() {
    let session = SessionBlock(card: .easyRun, intensity: .easy, durationMinLow: 35, durationMinHigh: 45)
    let state = SessionFeature.State(session: session)
    #expect(state.displayedSession == session)
  }
}
