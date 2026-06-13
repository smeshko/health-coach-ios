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
      // Route to Connect ONLY from `.main`: a 401 while in the app means a previously-valid session went
      // invalid, so bounce to Connect (token-invalid). The `.main → .onboarding` swap tears down the
      // in-flight Today orchestration via TCA's `ifCaseLet` child-effect teardown (§13). Do NOT cancel
      // `sessionStream`, do NOT re-subscribe, do NOT retry / refresh the token. While already
      // `.onboarding` (an active connect attempt) the event is a NO-OP: the Connect screen surfaces probe
      // failures inline, and reconstructing state here would wipe the typed token + flash the reason
      // banner mid-connect (the 7.2 double-bounce; DECISIONS 5).
      guard case .main = state.route else { return .none }
      state.route = .onboarding(OnboardingFeature.State(step: .connect(reason: .tokenInvalid)))
      return .none

    case ._restoreSession, ._tokenChecked, .onboarding, .main:
      // Handled in `AppFeature.body` (launch restore) / the child reducers — never routed here.
      return .none
    }
  }
}
