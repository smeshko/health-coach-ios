import ComposableArchitecture
import SwiftUI
#if DEBUG
  import DesignSystemGallery
#endif

/// The You-tab root view (ARCHITECTURE §4.5). **Minimal in Phase 7.4**: a plain grouped `List` whose
/// only content is a `#if DEBUG` **DEV** section with two rows — a TCA-routed **Dev Menu** push and a
/// plain **Component Gallery** push, both onto the You-tab navigation stack. In RELEASE the list renders
/// empty (Phase 10.2 fills the You tab with the real CONNECTION / APPLE HEALTH / PROFILE / REMINDERS
/// sections) and no DEV-section / dev-menu symbol exists. The Dev Menu push uses
/// `.navigationDestination(item:)` bound to the `@Presents var devMenu` state: the You tab already sits
/// in a `NavigationStack` (Phase 7.1), so this item-driven destination pushes/pops with no extra nav host.
public struct SettingsFeatureView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  public init(store: StoreOf<SettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    List {
      // Production sections (Phase 10.2 CONNECTION/APPLE HEALTH/PROFILE + Phase 10.3 REMINDERS).
      ConnectionSection(store: store)
      AppleHealthSection(store: store)
      ProfileConstantsSection(store: store)
      RemindersSection(store: store)
      #if DEBUG
        Section("Dev") {
          // The dev menu is TCA-routed (state-driven), so it's a Button with a manual disclosure chevron
          // rather than a NavigationLink; the gallery is a plain push (no state) onto the same You-tab
          // stack because `DesignSystemGalleryList` omits its own `NavigationStack`.
          Button {
            store.send(.devMenuTapped)
          } label: {
            HStack {
              Text("Dev Menu")
                .foregroundStyle(.primary)
              Spacer()
              Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
          }
          // ALLOWLIST (Phase 12.2 / DECISIONS D4): `.plain` here SUPPRESSES the `List`-row button
          // chrome (full-row highlight + chevron) so this custom row renders flat like its sibling
          // `NavigationLink` — it is not feedback-stripping, so it deliberately stays `.plain` (not
          // `.coachPressable`).
          .buttonStyle(.plain)

          NavigationLink("Component Gallery") {
            DesignSystemGalleryList()
          }
        }
      #endif
    }
    .navigationTitle("Settings")
    .onAppear { store.send(.onAppear) }
    // Push (not a sheet): SettingsFeatureView is the You-tab stack root, so this pushes onto it. No
    // wrapping `NavigationStack` — DevMenuView's own pushes (the log viewer) ride the same stack.
    #if DEBUG
      .navigationDestination(item: $store.scope(state: \.devMenu, action: \.devMenu)) { devStore in
        DevMenuView(store: devStore)
      }
    #endif
  }
}

#Preview {
  SettingsFeatureView(
    store: .init(
      initialState: .init(),
      reducer: SettingsFeature.init
    )
  )
}
