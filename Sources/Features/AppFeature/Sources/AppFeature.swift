import APIClient
import CoachCore
import ComposableArchitecture
import Foundation
import LogClient
import OnboardingFeature
import StrengthTestFeature
import TokenClient

/// The app root (ARCHITECTURE §10 / D7): the `route` is a sum type that is **either** onboarding **or**
/// the main tab bar — never both. **Happy-path-first** (personal app): the app starts in `.main` and, on
/// launch, a background token check (`tokenClient.read()`) falls back to `.onboarding` only when no bearer
/// token is CONFIRMED absent — a Keychain read ERROR stays put on `.main` (Phase 18.4: error ≠ absence;
/// swapping on a thrown read would strand a token-holding owner at onboarding). A successful Connect
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

  /// The launch token-read outcome (Phase 18.4) — three states, because error ≠ absence: `try?` used to
  /// collapse a thrown Keychain read into "no token" and swap a token-holding owner to onboarding.
  /// `public` deliberately: `Action` is public, so an internal payload type would be an access-control
  /// compile error. The `.tca` action log renders structural case labels only, never the `String`.
  public enum TokenRestore: Equatable, Sendable {
    /// A non-empty bearer token is stored — the happy path.
    case present
    /// The read succeeded and CONFIRMED no (or an empty) stored token — the only outcome that swaps
    /// the route to onboarding.
    case absent
    /// The Keychain read threw (e.g. keychain temporarily unavailable). Payload = the error/status
    /// description, carried solely for the diagnostic log line.
    case readFailed(String)
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
    /// A tapped local notification, forwarded by the app-target `UNUserNotificationCenterDelegate`
    /// (Phase 10.4) with the request identifier. The app-layer half of the 10.3 deep-link seam; kept
    /// driveable purely from a `String` so the mapping is fully unit-testable.
    case notificationOpened(identifier: String)
    /// An opened `coachapp://` URL (Phase 21.1), forwarded by `AppView`'s `.onOpenURL` — the app-layer
    /// half of the widget `widgetURL` seam. Parsed via `CoachDeepLink(url:)`; kept driveable purely
    /// from a `URL` so the routing is fully unit-testable.
    case deepLink(URL)
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
    /// The launch token-read outcome. Drives the `.main → .onboarding` fallback; a CONFIRMED
    /// `.absent` token is the only thing that swaps — `.readFailed` stays put (Phase 18.4).
    case _tokenChecked(TokenRestore)
    // swiftlint:enable identifier_name
  }

  /// AppFeature's cancellation namespace (DECISIONS #2). `sessionStream` keeps the 401 subscription
  /// alive for the whole process (never cancelled by the 401 handler). A 401 mid-orchestration is
  /// contained by TCA's `ifCaseLet` child-effect teardown on the `.main → .onboarding` swap (pinned
  /// by the 11.6 child-teardown test), not by a dedicated cancel ID.
  public enum CancelID: Hashable, Sendable { case sessionStream }

  /// Notification request identifiers the app routes on — the wire strings the 10.3 `ReminderScheduler`
  /// schedules. Held here as named constants rather than importing `SettingsFeature`'s internal
  /// `ReminderID` (the project's wire-raw-string convention; an `AppFeature → SettingsFeature` import for
  /// an internal would also be the wrong coupling).
  private enum NotificationRoute {
    static let weeklyStrengthTest = "reminder.weekly-strength-test"
  }

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
        // network (an invalid token is the 401 path's job; §13), so launch works offline. A thrown read
        // is its OWN outcome (Phase 18.4) — never collapsed into "no token".
        log.info("Restoring session — reading stored token", category: .lifecycle)
        return .run { [tokenClient] send in
          do {
            let token = try await tokenClient.read()
            await send(._tokenChecked(token?.isEmpty == false ? .present : .absent))
          } catch {
            await send(._tokenChecked(.readFailed("\(error)")))
          }
        }
      case let ._tokenChecked(outcome):
        // The launch token check resolved → the restore overlay can lift in EVERY arm (Phase 12.4, D1:
        // AppView crossfades from the launch color into the now-known screen).
        state.isRestoringSession = false
        switch outcome {
        case .present:
          log.info("Launch token check — staying put", category: .app, metadata: ["outcome": "present"])
          // Happy-path-first: stay in the default `.main` and drive the Today cache-first open from the
          // reducer (Phase 12.1, DECISIONS D8) — but ONLY while still in `.main` (a 401 may have already
          // routed us off it).
          guard case .main = state.route else { return .none }
          return .send(.main(.todayRoot(.onAppOpen)))
        case .absent:
          // The ONLY outcome that swaps: the read succeeded and confirmed no token. Never dispatches
          // `.onAppOpen`, so a token-less launch never hydrates cached health content before the swap.
          // Only-from-`.main` guard kept: don't stomp a route a 401 already changed.
          guard case .main = state.route else { return .none }
          log.info("Launch token absent — falling back to onboarding", category: .app)
          state.route = .onboarding(OnboardingFeature.State())
          return .none
        case let .readFailed(description):
          // A read ERROR is not absence — STAY PUT (no route change from `.main`) and still open Today
          // cache-first. Outcome spectrum: under a TRANSIENT keychain failure the next request's per-call
          // `tokenClient.read()` succeeds and everything proceeds; under a PERSISTENT one no request can
          // even be built (Transport reads the token before sending), so no 401 fires — the owner stays
          // on `.main` in a degraded route whose exact surface varies (a check-in-gated morning shows the
          // check-in card first; a cache-hit launch renders cached content with the background failure
          // deliberately quiet; a cache-miss sync shows the error state). The reliable trace is this
          // always-on `.http` record naming the keychain cause, not any one screen; relaunch recovers
          // transients. A dedicated recoverable auth/persistence error state with a foreground re-read is
          // DEFERRED (single-owner app, rare device-level failure).
          log.error("Launch token read FAILED (\(description)) — staying on main", category: .http)
          guard case .main = state.route else { return .none }
          return .send(.main(.todayRoot(.onAppOpen)))
        }
      case let .notificationOpened(identifier):
        // The app-layer half of the 10.3 deep-link seam. Only the weekly strength-test reminder routes;
        // the morning check-in reminder needs no route (fire-and-open). Map by the literal wire string —
        // `AppFeature` doesn't import `SettingsFeature`'s internal `ReminderID` (wire-raw-string convention).
        guard identifier == NotificationRoute.weeklyStrengthTest else { return .none }
        // A session-gated You-tab screen can only land on `.main`. Mutate the unwrapped `.main` state
        // explicitly (not via `mainRoute?`, which is a silent no-op while onboarding); a tap while
        // onboarding has nowhere to land, so it's dropped (accepted v1 behavior — PLAN.md:Risks).
        guard case var .main(main) = state.route else { return .none }
        main.selectedTab = .settings
        // De-dupe: don't stack a second strength-test screen if it's already on top (a double-tap).
        let alreadyOpen: Bool
        if case .strengthTest? = main.settings.last { alreadyOpen = true } else { alreadyOpen = false }
        if !alreadyOpen { main.settings.append(.strengthTest(StrengthTestFeature.State())) }
        state.route = .main(main)
        return .none
      case let .deepLink(url):
        // The `coachapp://` URL routing (Phase 21.1, DECISIONS D5). Guards mirror
        // `notificationOpened`: only-from-`.main` (dropped while onboarding — nowhere to land).
        guard let link = CoachDeepLink(url: url) else {
          log.notice("Unparseable deep link — dropped", category: .app, metadata: ["url": url.absoluteString])
          return .none
        }
        guard case var .main(main) = state.route else { return .none }
        switch link {
        case .today:
          main.selectedTab = .today
        case .weekly:
          main.selectedTab = .weekly
        case .checkIn:
          // The check-in flow IS the Today tab's `BriefViewState.checkInRequired` gate — an unlogged
          // day surfaces the check-in card by itself; the route only picks the tab (21.5 may
          // specialise this case without a new URL contract).
          main.selectedTab = .today
        }
        state.route = .main(main)
        log.info("Deep link routed", category: .app, metadata: ["url": url.absoluteString])
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
