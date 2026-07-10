import CoachCore
import ComposableArchitecture
import Foundation
import LogClient
import Testing

@testable import AppFeature

/// Asserts the app-root `.tca` action trace (`logActions()`): each action emits a `.debug` line whose
/// message is the action's case-label path, **never** its associated-value payload (no PII); and the
/// instrument only observes — reducer behaviour is unchanged.
@MainActor
struct ActionLoggingTests {
  @Test func test_actionLabel_loggedUnderTca_payloadFree() async {
    let recorder = LogRecorder()
    let store = TestStore(initialState: AppFeature.State(route: .main(MainTabs.State()))) {
      AppFeature()
    } withDependencies: {
      $0.calendar = .europeSofia
      $0.date = .constant(Date(timeIntervalSince1970: 0))
      $0.checkInRepository.current = { _ in nil } // the dispatched Today open lands at the gate
      $0.log = .recording(into: recorder)
    }
    // `._tokenChecked(.present)` now dispatches the Today cache-first open (D8); this test only cares
    // about the `.tca` log line, so don't assert the open chain exhaustively.
    store.exhaustivity = .off

    // A payload-bearing action: the renderer descends through the `TokenRestore` enum (structural case
    // labels) but stops at its non-enum `String` payload — the error description is never logged.
    await store.send(._tokenChecked(.readFailed("keychain-status-payload")))
    await store.skipReceivedActions()

    let tca = recorder.entries.filter { $0.category == .tca }
    #expect(tca.contains { $0.level == .debug && $0.message == "_tokenChecked.readFailed" })
    #expect(!tca.contains { $0.message.contains("keychain-status-payload") })
  }

  @Test func test_nestedAction_logsCaseLabelPath() async {
    let recorder = LogRecorder()
    let store = TestStore(initialState: AppFeature.State(route: .main(MainTabs.State()))) {
      AppFeature()
    } withDependencies: {
      $0.log = .recording(into: recorder)
    }

    var expected = MainTabs.State()
    expected.selectedTab = .weekly
    await store.send(.main(.tabSelected(.weekly))) {
      $0.route = .main(expected)
    }

    // The nested case-label path descends through enum associated values (all enums here).
    #expect(recorder.entries.contains { $0.category == .tca && $0.message == "main.tabSelected.weekly" })
  }
}
