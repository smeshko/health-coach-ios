import APIClient
import ComposableArchitecture
import LogClient
import OnboardingFeature
import Testing

@testable import AppFeature

/// Asserts the app-spine observability lines (`.app` / `.lifecycle`) emitted via `@Dependency(\.log)` —
/// the connect swap, the token reset, the launch session restore, and app-will-appear. Each injects a
/// `LogClient.recording(into:)` recorder and asserts the captured entry (category + a stable message
/// fragment); messages are label-only (no payloads / PII).
@MainActor
struct AppFeatureLogTests {
  @Test func test_connected_emitsAppLog() async {
    let recorder = LogRecorder()
    let store = TestStore(initialState: AppFeature.State.onboarding(OnboardingFeature.State())) {
      AppFeature()
    } withDependencies: {
      $0.log = .recording(into: recorder)
    }

    await store.send(.onboarding(.delegate(.connected))) {
      $0 = .main(MainTabs.State())
    }

    #expect(recorder.entries.contains { $0.category == .app && $0.message.contains("Connected") })
  }

  @Test func test_tokenReset_emitsAppLog() async {
    let recorder = LogRecorder()
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.log = .recording(into: recorder)
    }

    await store.send(.main(.delegate(.tokenReset))) {
      $0 = .onboarding(OnboardingFeature.State())
    }

    #expect(recorder.entries.contains { $0.category == .app && $0.message.contains("Token reset") })
  }

  @Test func test_restoreSession_noToken_emitsLifecycleAndAppLogs() async {
    let recorder = LogRecorder()
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.tokenClient.read = { nil }
      $0.log = .recording(into: recorder)
    }

    await store.send(._restoreSession)
    await store.receive(\._tokenChecked, false) {
      $0 = .onboarding(OnboardingFeature.State())
    }

    #expect(recorder.entries.contains { $0.category == .lifecycle && $0.message.contains("Restoring session") })
    #expect(recorder.entries.contains { $0.category == .app && $0.message.contains("falling back to onboarding") })
  }

  @Test func test_appWillAppear_emitsLifecycleLog() async {
    let recorder = LogRecorder()
    let (stream, continuation) = AsyncStream.makeStream(of: SessionEvent.self)
    let store = TestStore(initialState: AppFeature.State.main(MainTabs.State())) {
      AppFeature()
    } withDependencies: {
      $0.apiClient.sessionEvents = { stream }
      $0.log = .recording(into: recorder)
    }

    await store.send(._appWillAppear)

    #expect(recorder.entries.contains { $0.category == .lifecycle && $0.message.contains("App will appear") })

    continuation.finish()
    await store.finish()
  }
}
