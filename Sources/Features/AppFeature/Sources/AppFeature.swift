import APIClient
import ComposableArchitecture
import OnboardingFeature
import TokenClient

/// The app root (ARCHITECTURE §10 / D7): a sum type that is **either** onboarding **or** the main tab
/// bar — never both. **Happy-path-first** (personal app): the app starts in `.main` and, on launch, a
/// background token check (`tokenClient.read()`) falls back to `.onboarding` only when no bearer token
/// is stored — the no-token / first-run case is the edge case, not the default. A successful Connect
/// flips `.onboarding → .main` on the `connected` delegate, and the 401 effect flips `.main →
/// .onboarding` at the Connect step with `reason: .tokenInvalid` (see `AppFeature+SessionRouting.swift`).
/// An *invalid* (vs absent) token is caught by that 401 path on the first request, not by the launch
/// check — so launch stays offline-friendly (no blocking probe; §14 cache serves first).
@Reducer
public struct AppFeature {
  @ObservableState
  public enum State: Equatable {
    case onboarding(OnboardingFeature.State)
    case main(MainTabs.State)

    /// The app starts in `.main` (happy path); the launch token check swaps to `.onboarding` when no
    /// token is stored.
    public init() { self = .main(MainTabs.State()) }
  }

  public enum Action {
    case onboarding(OnboardingFeature.Action)
    case main(MainTabs.Action)
    // Internal actions use TCA's `_`-prefix convention (not part of the feature's public contract);
    // the leading underscore trips `identifier_name`, so scope a disable to these two cases.
    // swiftlint:disable identifier_name
    /// View-lifecycle trigger — sent **once per process** from `AppView`'s single non-re-mounting
    /// outer container so the single-subscriber session stream is opened exactly once (never on a
    /// branch swap). The reducer never self-sends it.
    case _appWillAppear
    /// A session-level event delivered by the `apiClient.sessionEvents()` subscription.
    case _sessionEvent(SessionEvent)
    /// App-open session restore — sent once from `AppView`'s launch hook: reads the stored bearer token
    /// in the background so the default `.main` falls back to onboarding only when none exists.
    case _restoreSession
    /// The launch token-read result (`true` = a non-empty token is stored). Drives the `.main →
    /// .onboarding` fallback; an empty/absent token is the only thing that swaps.
    case _tokenChecked(hasToken: Bool)
    // swiftlint:enable identifier_name
  }

  /// AppFeature's cancellation namespace (DECISIONS #2). `sessionStream` keeps the 401 subscription
  /// alive for the whole process (never cancelled by the 401 handler); `appWork` is the bucket for the
  /// app-open orchestration (Epic 8) that a 401 must clear.
  public enum CancelID: Hashable, Sendable { case sessionStream, appWork }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.tokenClient) var tokenClient

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onboarding(.delegate(.connected)):
        // Onboarding finished → swap in the tab bar.
        state = .main(MainTabs.State())
        return .none
      case .main(.delegate(.tokenReset)):
        // The You tab cleared the session (the DEBUG dev menu's "reset token", or Phase 10.2's
        // Disconnect row) → swap back to onboarding so the connect flow can be re-run without relaunch.
        state = .onboarding(OnboardingFeature.State())
        return .none
      case ._appWillAppear, ._sessionEvent:
        return reduceSessionRouting(into: &state, action: action)
      case ._restoreSession:
        // Background token check: read the stored bearer token off the launch path. We don't probe the
        // network (an invalid token is the 401 path's job; §13), so launch works offline.
        return .run { [tokenClient] send in
          let token = try? await tokenClient.read()
          await send(._tokenChecked(hasToken: token?.isEmpty == false))
        }
      case let ._tokenChecked(hasToken):
        // Happy-path-first: stay in the default `.main` when a token exists; fall back to onboarding only
        // for the no-token edge case, and only if a 401 hasn't already routed us off `.main`.
        guard !hasToken, case .main = state else { return .none }
        state = .onboarding(OnboardingFeature.State())
        return .none
      case .onboarding, .main:
        return .none
      }
    }
    .ifCaseLet(\.onboarding, action: \.onboarding) {
      OnboardingFeature()
    }
    .ifCaseLet(\.main, action: \.main) {
      MainTabs()
    }
  }
}
