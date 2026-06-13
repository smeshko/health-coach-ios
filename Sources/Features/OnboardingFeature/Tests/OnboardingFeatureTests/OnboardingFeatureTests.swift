import ComposableArchitecture
import Testing

@testable import OnboardingFeature

/// Audit gap #5: the OnboardingFeature step machine had ZERO tests on the two seams the whole flow
/// hangs on — `connect(.delegate(.connected))` → `.healthKitPriming` (with a FRESH priming child, the
/// "never a stale `.degraded` on re-entry" contract) and `healthKitPriming(.delegate(.finished))` →
/// `Delegate.connected`.
@MainActor
struct OnboardingFeatureTests {
  @Test func test_connectConnected_advancesToPriming_withFreshChild() async {
    // Seed a stale degraded priming child to prove the advance RESETS it (the doc-comment contract).
    var initial = OnboardingFeature.State(step: .connect(reason: nil))
    initial.healthKitPriming = HealthKitPriming.State(
      phase: .degraded(HealthKitPriming.DegradedSummary(missing: [.sleep])),
      missingRows: [.sleep]
    )
    let store = TestStore(initialState: initial) {
      OnboardingFeature()
    }

    await store.send(.connect(.delegate(.connected))) {
      $0.healthKitPriming = HealthKitPriming.State() // reset to a fresh `.priming`
      $0.step = .healthKitPriming
    }
    #expect(store.state.healthKitPriming.phase == .priming, "re-entry must not carry a stale .degraded")
  }

  @Test func test_primingFinished_emitsConnectedDelegate() async {
    let store = TestStore(initialState: OnboardingFeature.State(step: .healthKitPriming)) {
      OnboardingFeature()
    }

    await store.send(.healthKitPriming(.delegate(.finished)))
    await store.receive(\.delegate, .connected)
  }
}
