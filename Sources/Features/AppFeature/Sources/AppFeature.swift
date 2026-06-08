import ComposableArchitecture

/// The app root (ARCHITECTURE §10 / D7): a sum type that is **either** onboarding **or** the main tab
/// bar — never both. The app starts in `.onboarding` and flips to `.main` on the onboarding `connected`
/// delegate; the 401 effect (TASK-002) flips `.main → .onboarding` at the Connect step with
/// `reason: .tokenInvalid`.
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
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onboarding(.delegate(.connected)):
        // Onboarding finished → swap in the tab bar.
        state = .main(MainTabs.State())
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
