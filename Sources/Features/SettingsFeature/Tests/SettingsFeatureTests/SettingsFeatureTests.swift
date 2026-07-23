#if DEBUG
  import ComposableArchitecture
  import Testing

  @testable import SettingsFeature

  /// `TestStore` coverage for the You-tab root's DEBUG DEV surface: tapping "Dev Menu" presents the
  /// menu, a dismiss clears it, and the dev menu's `tokenReset` delegate dismisses the sheet **and**
  /// bubbles `SettingsFeature.Delegate.tokenReset` up to the shell.
  @MainActor
  struct SettingsFeatureTests {
    /// One present→dismiss round-trip (audit MERGE: the former test_devMenuTapped_presentsDevMenu +
    /// test_devMenuDismissed_clearsDevMenu).
    @Test func test_devMenu_presentThenDismiss_roundTrips() async {
      let store = TestStore(initialState: SettingsFeature.State()) {
        SettingsFeature()
      }

      await store.send(.devMenuTapped) {
        $0.devMenu = DevMenuFeature.State()
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

    /// The dev menu's full-re-sync delegate clears the watermark anchor via the repository seam the
    /// parent owns; the sheet stays presented (nothing to navigate).
    @Test func test_devMenuFullResync_clearsWatermarkAnchor() async {
      let reset = LockIsolated(false)
      var initial = SettingsFeature.State()
      initial.devMenu = DevMenuFeature.State()
      let store = TestStore(initialState: initial) {
        SettingsFeature()
      } withDependencies: {
        $0.syncRepository.resetWatermark = { reset.setValue(true) }
      }

      await store.send(.devMenu(.presented(.delegate(.fullResyncRequested))))
      await store.finish()

      #expect(reset.value, "the delegate must clear the sync watermark anchor")
    }
  }
#endif
