#if DEBUG
  import ComposableArchitecture
  import LogClient

  /// The DEBUG on-device log viewer (Phase 7.4). Loads recent log lines from
  /// `@Dependency(\.log).readRecent()` — the live `LogClient` reads the rotating `Caches/Logs/` files —
  /// and re-loads on demand. Read-only; the whole file is `#if DEBUG`, so it compiles out of RELEASE. It
  /// touches only the `LogClient` **interface** (no `*Live`), so the next reload reflects whatever has
  /// been written since.
  @Reducer
  public struct LogViewerFeature {
    @ObservableState
    public struct State: Equatable {
      /// Recent log lines, oldest→newest (the view renders them newest-first).
      public var lines: [String] = []
      public var isLoading = false
      public init(lines: [String] = []) {
        self.lines = lines
      }
    }

    public enum Action: Equatable {
      case onAppear
      case refreshTapped
      case logsLoaded([String])
    }

    @Dependency(\.log) var log

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .onAppear, .refreshTapped:
          state.isLoading = true
          return .run { [log] send in
            await send(.logsLoaded(log.readRecent()))
          }
        case let .logsLoaded(lines):
          state.isLoading = false
          state.lines = lines
          return .none
        }
      }
    }
  }
#endif
