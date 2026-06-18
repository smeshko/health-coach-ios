import ComposableArchitecture
import DesignSystem
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
  @Environment(\.scenePhase) private var scenePhase

  public init(store: StoreOf<SettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    List {
      // Production sections: CONNECTION, STRENGTH (#2 — review), PROFILE (Phase 10.2), REMINDERS
      // (Phase 10.3). The APPLE HEALTH "categories shared" section was dropped (review) along with its
      // probe. Rows sit on `coachSurface` over a `coachBackground` page so the You tab matches the
      // Today/Week tabs (hides the system grouped-grey List background).
      ConnectionSection(store: store)
        .listRowBackground(Color.coachSurface)
      StrengthTestSection(store: store)
        .listRowBackground(Color.coachSurface)
      ProfileConstantsSection(store: store)
        .listRowBackground(Color.coachSurface)
      RemindersSection(store: store)
        .listRowBackground(Color.coachSurface)
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
        .listRowBackground(Color.coachSurface)
      #endif
    }
    .scrollContentBackground(.hidden)
    .background(Color.coachBackground)
    .navigationTitle("Settings")
    .onAppear { store.send(.onAppear) }
    // Returning from iOS Settings (the "allow notifications" hint) backgrounds the app without
    // unmounting this view, so `.onAppear` won't re-fire — refresh on scene re-activation so a
    // permission granted/revoked there is reflected (and reminders reconciled) (review #1.1).
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active { store.send(.onAppear) }
    }
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
