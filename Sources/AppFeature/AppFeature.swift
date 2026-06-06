import ComposableArchitecture

@Reducer
public struct AppFeature {
  @ObservableState
  public struct State: Equatable {
    public init() {}
  }

  public enum Action {
    case onAppear
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { _, action in
      switch action {
      case .onAppear:
        return .none
      }
    }
  }
}
