import ComposableArchitecture
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
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.log = .recording(into: recorder)
    }

    // A payload-bearing action: only the case label is logged, never `hasToken: true`.
    await store.send(._tokenChecked(hasToken: true))

    let tca = recorder.entries.filter { $0.category == .tca }
    #expect(tca.contains { $0.level == .debug && $0.message == "_tokenChecked" })
    #expect(!tca.contains { $0.message.contains("true") || $0.message.contains("hasToken") })
  }

  @Test func test_nestedAction_logsCaseLabelPath() async {
    let recorder = LogRecorder()
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.log = .recording(into: recorder)
    }

    var expected = MainTabs.State()
    expected.selectedTab = .weekly
    await store.send(.main(.tabSelected(.weekly))) {
      $0 = .main(expected)
    }

    // The nested case-label path descends through enum associated values (all enums here).
    #expect(recorder.entries.contains { $0.category == .tca && $0.message == "main.tabSelected.weekly" })
  }
}
