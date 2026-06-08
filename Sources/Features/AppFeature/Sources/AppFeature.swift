import APIClient
import ComposableArchitecture

/// The app root (ARCHITECTURE §10 / D7): a sum type that is **either** onboarding **or** the main tab
/// bar — never both. The app starts in `.onboarding` and flips to `.main` on the onboarding `connected`
/// delegate; the 401 effect flips `.main → .onboarding` at the Connect step with `reason: .tokenInvalid`
/// (see `AppFeature+SessionRouting.swift`).
@Reducer
public struct AppFeature {
  @ObservableState
  public enum State: Equatable {
    case onboarding(OnboardingFeature.State)
    case main(MainTabs.State)

    /// The app starts in onboarding (shown until connected + authorized).
    public init() { self = .onboarding(OnboardingFeature.State()) }
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
    // swiftlint:enable identifier_name
  }

  /// AppFeature's cancellation namespace (DECISIONS #2). `sessionStream` keeps the 401 subscription
  /// alive for the whole process (never cancelled by the 401 handler); `appWork` is the bucket for the
  /// app-open orchestration (Epic 8) that a 401 must clear.
  public enum CancelID: Hashable, Sendable { case sessionStream, appWork }

  @Dependency(\.apiClient) var apiClient

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onboarding(.delegate(.connected)):
        // Onboarding finished → swap in the tab bar.
        state = .main(MainTabs.State())
        return .none
      case ._appWillAppear, ._sessionEvent:
        return reduceSessionRouting(into: &state, action: action)
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
