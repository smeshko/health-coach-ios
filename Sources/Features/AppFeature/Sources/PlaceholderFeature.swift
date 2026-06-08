import ComposableArchitecture

/// A tiny shared placeholder destination feature. Each per-tab `*Path` carries one `placeholder` case
/// so the `StackState`/`.forEach` plumbing is real and pushable — `StackAction.push(id:state:)` needs a
/// concrete `State` value, which an uninhabited enum cannot provide. The real destinations are filled
/// in by Epics 8 (Today), 9 (Week), and 10 (You/Settings).
@Reducer
public struct PlaceholderFeature {
  @ObservableState
  public struct State: Equatable {
    public init() {}
  }

  public enum Action: Equatable {
    /// Inert — placeholder destinations have no behavior in Phase 7.1. A single (unused) case keeps the
    /// `Action` enum inhabited; an empty enum trips the `@Reducer`/CasePaths macro expansion.
    case noop
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}
