#if DEBUG
  import ComposableArchitecture
  import Testing

  @testable import SettingsFeature

  /// `TestStore` coverage for the You-tab root's DEBUG DEV surface: tapping "Dev Menu" presents the
  /// menu, a dismiss clears it, and the dev menu's `tokenReset` delegate dismisses the sheet **and**
  /// bubbles `SettingsFeature.Delegate.tokenReset` up to the shell.
  @MainActor
  struct SettingsFeatureTests {
    @Test func test_devMenuTapped_presentsDevMenu() async {
      let store = TestStore(initialState: SettingsFeature.State()) {
        SettingsFeature()
      }

      await store.send(.devMenuTapped) {
        $0.devMenu = DevMenuFeature.State()
      }
    }

    @Test func test_devMenuDismissed_clearsDevMenu() async {
      var initial = SettingsFeature.State()
      initial.devMenu = DevMenuFeature.State()
      let store = TestStore(initialState: initial) {
        SettingsFeature()
      }

      await store.send(.devMenu(.dismiss)) {
        $0.devMenu = nil
      }
    }

    @Test func test_devMenuTokenReset_dismissesAndBubblesDelegate() async {
      var initial = SettingsFeature.State()
      initial.devMenu = DevMenuFeature.State()
      let store = TestStore(initialState: initial) {
        SettingsFeature()
      }

      await store.send(.devMenu(.presented(.delegate(.tokenReset)))) {
        $0.devMenu = nil
      }
      await store.receive(\.delegate, .tokenReset)
    }
  }
#endif
