import APIClient
import ComposableArchitecture
import LogClient
import OnboardingFeature
import TokenClient

/// The app root (ARCHITECTURE §10 / D7): the `route` is a sum type that is **either** onboarding **or**
/// the main tab bar — never both. **Happy-path-first** (personal app): the app starts in `.main` and, on
/// launch, a background token check (`tokenClient.read()`) falls back to `.onboarding` only when no bearer
/// token is stored — the no-token / first-run case is the edge case, not the default. A successful Connect
/// flips the route `.onboarding → .main` on the `connected` delegate, and the 401 effect flips `.main →
/// .onboarding` at the Connect step with `reason: .tokenInvalid` (see `AppFeature+SessionRouting.swift`).
/// An *invalid* (vs absent) token is caught by that 401 path on the first request, not by the launch
/// check — so launch stays offline-friendly (no blocking probe; §14 cache serves first).
///
/// Phase 12.4 (D1) wraps the sum type in a struct (`route` + `isRestoringSession`) instead of adding a
/// third `.launching` case: `isRestoringSession` starts `true` and `AppView` lays an app-colored overlay
/// over the route until `._tokenChecked` clears it — so a token-less launch never flashes MainTabs chrome
/// and a token launch never flashes onboarding, while the route sum type and happy-path-first mounting
/// (MainTabs mounts immediately; 12.1's D8 still gates orchestration) survive untouched.
@Reducer
public struct AppFeature {
  /// The app root sum type — **either** onboarding **or** main, never both (D7). A sibling of `State` (not
  /// nested inside it) to stay within the 1-level nesting lint; `State.route` holds it.
  public enum Route: Equatable {
    case onboarding(OnboardingFeature.State)
    case main(MainTabs.State)
  }

  @ObservableState
  public struct State: Equatable {
    /// The app root sum type (`AppFeature.Route`) — **either** onboarding **or** main, never both (D7). The
    /// struct wrap (Phase 12.4) keeps the contract while adding the launch-restore flag alongside it.
    public var route: Route
    /// `true` from launch until the launch token check (`._tokenChecked`) resolves (Phase 12.4, D1).
    /// While it holds, `AppView`'s app-colored overlay hides the route, so the first *visible* frame is
    /// already the resolved screen — killing both the white flash and the wrong-state flicker.
    public var isRestoringSession: Bool

    /// The app starts in `.main` (happy path), restoring; the launch token check swaps the route to
    /// `.onboarding` when no token is stored and clears `isRestoringSession` either way.
    public init() {
      self.init(route: .main(MainTabs.State()), isRestoringSession: true)
    }

    /// Explicit construction (tests / specific routes). `isRestoringSession` defaults to `false` — a
    /// constructed-at-a-known-route state is past restore — so test fixtures and snapshots read terse and
    /// the overlay never blanks them.
    public init(route: Route, isRestoringSession: Bool = false) {
      self.route = route
      self.isRestoringSession = isRestoringSession
    }

    /// Optional projection of the `.onboarding` route for `ifLet`/`store.scope` (Phase 12.4): `get` reads
    /// the associated state when the route is onboarding, `set` re-embeds it. The explicit accessors keep
    /// the struct wrap working with TCA's optional-keypath operators (the macro case-key-path didn't
    /// resolve to an optional `WritableKeyPath` here). Setting `nil` is unreachable (the route is always
    /// one case or the other; TCA only writes back non-nil child state) and is a no-op.
    public var onboardingRoute: OnboardingFeature.State? {
      get { if case let .onboarding(state) = route { state } else { nil } }
      set { if let newValue { route = .onboarding(newValue) } }
    }

    /// Optional projection of the `.main` route — mirror of `onboardingRoute`.
    public var mainRoute: MainTabs.State? {
      get { if case let .main(state) = route { state } else { nil } }
      set { if let newValue { route = .main(newValue) } }
    }
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
  /// alive for the whole process (never cancelled by the 401 handler). A 401 mid-orchestration is
  /// contained by TCA's `ifCaseLet` child-effect teardown on the `.main → .onboarding` swap (pinned
  /// by the 11.6 child-teardown test), not by a dedicated cancel ID.
  public enum CancelID: Hashable, Sendable { case sessionStream }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.tokenClient) var tokenClient
  @Dependency(\.log) var log

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onboarding(.delegate(.connected)):
        // Onboarding finished → swap in the tab bar AND kick off the Today cache-first open. The open
        // trigger is reducer-owned (Phase 12.1, DECISIONS D8): cache-first removed the old incidental
        // auth guard (token-less launches used to die at the token-protected `sync()`), so dispatching
        // `.onAppOpen` only from a token-bearing branch is what keeps a token-less launch from ever
        // hydrating cached health content before the onboarding swap.
        log.info("Connected — switching onboarding → main", category: .app)
        state.route = .main(MainTabs.State())
        return .send(.main(.todayRoot(.onAppOpen)))
      case .main(.delegate(.tokenReset)):
        // The You tab cleared the session (the DEBUG dev menu's "reset token", or Phase 10.2's
        // Disconnect row) → swap back to onboarding so the connect flow can be re-run without relaunch.
        log.info("Token reset — switching main → onboarding", category: .app)
        state.route = .onboarding(OnboardingFeature.State())
        return .none
      case ._appWillAppear:
        log.info("App will appear — opening session-event stream", category: .lifecycle)
        return reduceSessionRouting(into: &state, action: action)
      case ._sessionEvent:
        return reduceSessionRouting(into: &state, action: action)
      case ._restoreSession:
        // Background token check: read the stored bearer token off the launch path. We don't probe the
        // network (an invalid token is the 401 path's job; §13), so launch works offline.
        log.info("Restoring session — reading stored token", category: .lifecycle)
        return .run { [tokenClient] send in
          let token = try? await tokenClient.read()
          await send(._tokenChecked(hasToken: token?.isEmpty == false))
        }
      case let ._tokenChecked(hasToken):
        // The launch token check resolved → the restore overlay can lift either way (Phase 12.4, D1: clear
        // in BOTH arms so AppView crossfades from the launch color into the now-known screen).
        state.isRestoringSession = false
        // Happy-path-first: stay in the default `.main` when a token exists; fall back to onboarding only
        // for the no-token edge case, and only if a 401 hasn't already routed us off `.main`.
        guard !hasToken, case .main = state.route else {
          log.info("Launch token check — staying put", category: .app, metadata: ["hasToken": "\(hasToken)"])
          // Staying put. Drive the Today cache-first open from the reducer (Phase 12.1, DECISIONS D8) —
          // but ONLY while still in `.main` (a token exists; or a 401 hasn't already routed us off it). A
          // token-less launch falls through to the onboarding swap below and never reaches this dispatch,
          // so it never hydrates cached health content before the swap.
          guard case .main = state.route else { return .none }
          return .send(.main(.todayRoot(.onAppOpen)))
        }
        log.info("Launch token absent — falling back to onboarding", category: .app)
        state.route = .onboarding(OnboardingFeature.State())
        return .none
      case .onboarding, .main:
        return .none
      }
    }
    .ifLet(\.onboardingRoute, action: \.onboarding) {
      OnboardingFeature()
    }
    .ifLet(\.mainRoute, action: \.main) {
      MainTabs()
    }
    // App-root `.tca` action trace (DECISIONS #4) — label-only, gated by the per-category DevSettings
    // toggle in `LogClientLive`. Outermost so it observes every action entering the root exactly once.
    .logActions()
  }
}
