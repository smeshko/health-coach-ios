import ComposableArchitecture
import SwiftUI

/// The You-tab root view (ARCHITECTURE §4.5). **Minimal in Phase 7.4**: its only content is a
/// `#if DEBUG` **DEV** section with a "Dev Menu" row that presents `DevMenuView` via `.sheet`. In
/// RELEASE the `Form` renders empty (Phase 10.2 fills the You tab) and no DEV-section / dev-menu symbol
/// exists. A `.sheet` (not a `SettingsPath` push) is used so the whole presentation is `#if DEBUG`
/// without a DEBUG-conditional `SettingsPath` case; the You tab already sits in a `NavigationStack`
/// (Phase 7.1), so the sheet renders with no nav-host caveat.
public struct SettingsFeatureView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  public init(store: StoreOf<SettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    Form {
      #if DEBUG
        Section("DEV") {
          Button("Dev Menu") { store.send(.devMenuTapped) }
        }
      #endif
    }
    .navigationTitle("Settings")
    #if DEBUG
      .sheet(item: $store.scope(state: \.devMenu, action: \.devMenu)) { devStore in
        NavigationStack { DevMenuView(store: devStore) }
      }
    #endif
  }
}
