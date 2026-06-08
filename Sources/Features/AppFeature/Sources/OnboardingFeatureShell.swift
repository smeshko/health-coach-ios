import ComposableArchitecture

/// The onboarding branch of `AppFeature` — **scaffolded, not implemented** in Phase 7.1.
///
/// This phase only needs enough of an onboarding feature to drive the `.onboarding ↔ .main` switch and
/// to receive the 401 route (`reason: .tokenInvalid`). The real Connect (token paste / `GET /probe`)
/// and HealthKit-priming/degraded screens land in Phases 7.2 / 7.3, which flesh out the `Step` enum and
/// wire `connectTapped` to real validation. Keeping it a shell here holds 7.1 to its stated deliverable
/// (the shell + 401 routing) without pre-building 7.2/7.3.
@Reducer
public struct OnboardingFeature {
  /// Why the Connect step is being shown. `nil` is a first-run/neutral prompt; `.tokenInvalid` is the
  /// state `AppFeature` routes to on a 401 (`SessionEvent.unauthorized`). Lives here because it is
  /// onboarding-presentation state (PLAN.md inline decision).
  public enum ConnectReason: Equatable { case tokenInvalid }

  /// The onboarding step. Held flat on the feature (not nested inside `State`) to stay within the
  /// project's 1-level type-nesting lint rule. `.healthKit` / `.degraded` steps arrive with Phase 7.3.
  public enum Step: Equatable {
    case connect(reason: ConnectReason?)
  }

  /// Delegate actions the parent (`AppFeature`) listens for. Flat on the feature (not nested inside
  /// `Action`) to satisfy the 1-level type-nesting lint rule.
  public enum Delegate: Equatable {
    /// The token is connected and authorized — `AppFeature` flips `.onboarding → .main`.
    case connected
  }

  @ObservableState
  public struct State: Equatable {
    public var step: Step

    public init(step: Step = .connect(reason: nil)) {
      self.step = step
    }
  }

  public enum Action {
    /// Stub success trigger — Phase 7.2 replaces this with a real `GET /probe` validation flow.
    case connectTapped
    case delegate(Delegate)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { _, action in
      switch action {
      case .connectTapped:
        // Stub: until Phase 7.2 wires `GET /probe`, tapping Connect succeeds immediately.
        .send(.delegate(.connected))
      case .delegate:
        .none
      }
    }
  }
}
