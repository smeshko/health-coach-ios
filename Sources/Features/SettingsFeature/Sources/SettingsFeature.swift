import ComposableArchitecture

/// The You-tab root reducer (ARCHITECTURE §4.5 / §10). **Minimal in Phase 7.4**: its only production
/// surface is a `tokenReset` delegate seam (the route-to-onboarding the shell owns — D7), and the only
/// *rendered* content is a `#if DEBUG` **DEV** section (see `SettingsFeatureView`) that presents the
/// `DevMenuFeature`. Phase 10.2 expands this same target with the production CONNECTION / APPLE HEALTH /
/// PROFILE / REMINDERS sections; this phase keeps the DEV slice self-contained so 10.2 leaves it
/// untouched.
@Reducer
public struct SettingsFeature {
  /// Delegate actions the shell (`MainTabs` → `AppFeature`) listens for. `tokenReset` asks the root to
  /// clear the session and return to onboarding. In this phase it is fired only by the DEBUG dev menu's
  /// reset action; it is also the seam Phase 10.2's production "Disconnect / Sign out" row reuses, so it
  /// (and the shell routing it drives) lives in production — only the dev-menu *trigger* is `#if DEBUG`.
  public enum Delegate: Equatable {
    case tokenReset
  }

  @ObservableState
  public struct State: Equatable {
    #if DEBUG
      /// The presented DEBUG dev menu (DEV section → "Dev Menu" row). Absent in RELEASE.
      @Presents public var devMenu: DevMenuFeature.State?
    #endif
    public init() {}
  }

  public enum Action {
    case delegate(Delegate)
    #if DEBUG
      case devMenuTapped
      case devMenu(PresentationAction<DevMenuFeature.Action>)
    #endif
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none
      #if DEBUG
        case .devMenuTapped:
          state.devMenu = DevMenuFeature.State()
          return .none
        case .devMenu(.presented(.delegate(.tokenReset))):
          // The dev menu cleared the bearer token → dismiss the sheet and bubble the route-to-onboarding
          // up to the shell (navigation lives at the root — D7).
          state.devMenu = nil
          return .send(.delegate(.tokenReset))
        case .devMenu:
          return .none
      #endif
      }
    }
    #if DEBUG
    .ifLet(\.$devMenu, action: \.devMenu) { DevMenuFeature() }
    #endif
  }
}
