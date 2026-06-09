import ComposableArchitecture

/// The onboarding branch of `AppFeature` (ARCHITECTURE §4.5 / §10): a step machine shown until the app
/// is **connected + HealthKit-authorized**. Phase 7.2 builds the `.connect` step (`ConnectComponent`);
/// the `.healthKitPriming` step is a placeholder here and is fleshed out in Phase 7.3.
///
/// **Two distinct `connected` delegates — keep them separate:**
/// - `ConnectComponent.Delegate.connected` (child → here) means "the token validated"; the parent's
///   reaction is to advance to `.healthKitPriming` (NOT to `.main`, and NOT by re-emitting its own
///   `.delegate(.connected)`).
/// - `OnboardingFeature.Delegate.connected` (here → `AppFeature`) means "onboarding is fully done"
///   (connected **and** HK-authorized) and flips `.onboarding → .main`. It fires only after the HK step
///   completes — wired in Phase 7.3. (`AppFeature` already handles it; the trigger moves from the old
///   7.1 connect stub onto the HK step.)
@Reducer
public struct OnboardingFeature {
  /// Why the Connect step is being shown. `nil` is a first-run/neutral prompt; `.tokenInvalid` is the
  /// state `AppFeature` routes to on a 401 (`SessionEvent.unauthorized`, §13/D13).
  public enum ConnectReason: Equatable { case tokenInvalid }

  /// The onboarding step. Held flat on the feature (not nested inside `State`) to stay within the
  /// project's 1-level type-nesting lint rule. `.healthKitPriming` is a placeholder until Phase 7.3.
  public enum Step: Equatable {
    case connect(reason: ConnectReason?)
    case healthKitPriming
  }

  /// Delegate actions `AppFeature` listens for. Flat on the feature (1-level nesting rule).
  public enum Delegate: Equatable {
    /// Onboarding is complete (connected **and** HK-authorized) — `AppFeature` flips `.onboarding →
    /// .main`. Emitted once the HK step lands (Phase 7.3); not the same as `ConnectComponent`'s
    /// `.connected`.
    case connected
  }

  @ObservableState
  public struct State: Equatable {
    public var step: Step
    /// The Connect step's child state. Always present (the connect field survives a step advance); the
    /// view renders it only while `step == .connect`.
    public var connect: ConnectComponent.State

    public init(step: Step = .connect(reason: nil)) {
      self.step = step
      connect = ConnectComponent.State()
    }
  }

  public enum Action {
    case connect(ConnectComponent.Action)
    case delegate(Delegate)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Scope(state: \.connect, action: \.connect) {
      ConnectComponent()
    }
    Reduce { state, action in
      switch action {
      case .connect(.delegate(.connected)):
        // Token validated → advance to HealthKit priming (Phase 7.3). NOT a route to `.main` and NOT
        // the parent's own `.delegate(.connected)` (§10/§4.5 keep onboarding until connected + HK-auth).
        state.step = .healthKitPriming
        return .none
      case .connect, .delegate:
        return .none
      }
    }
  }
}
