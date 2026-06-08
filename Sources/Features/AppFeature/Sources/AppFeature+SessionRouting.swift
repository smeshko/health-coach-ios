import APIClient
import ComposableArchitecture
import OnboardingFeature

/// The global 401 path (ARCHITECTURE §13 / D12 / D13, PRD §8.4): a single long-running effect
/// subscribes to `apiClient.sessionEvents()` and, on `.unauthorized`, clears in-flight app-spine work
/// and swaps the state to `.onboarding(.connect, reason: .tokenInvalid)` — with **no retry loop and no
/// re-subscribe**.
extension AppFeature {
  func reduceSessionRouting(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case ._appWillAppear:
      // Open the single-subscriber session stream exactly once. `cancelInFlight: true` only dedupes
      // concurrent copies — the once-per-process guarantee is enforced at the view layer (TASK-003
      // attaches the lifecycle hook to a non-re-mounting outer container). This effect is NEVER
      // cancelled by the 401 handler, so the subscription survives an onboarding↔main swap (no
      // subscribe/retry storm — the §13 anti-pattern).
      return .run { [apiClient] send in
        for await event in apiClient.sessionEvents() {
          await send(._sessionEvent(event))
        }
      }
      .cancellable(id: CancelID.sessionStream, cancelInFlight: true)

    case ._sessionEvent(.unauthorized):
      // Route to Connect with the token-invalid reason and clear in-flight app work (§13). Do NOT
      // cancel `sessionStream`, do NOT re-subscribe, do NOT retry / refresh the token.
      state = .onboarding(OnboardingFeature.State(step: .connect(reason: .tokenInvalid)))
      return .cancel(id: CancelID.appWork)

    case .onboarding, .main:
      return .none
    }
  }
}
