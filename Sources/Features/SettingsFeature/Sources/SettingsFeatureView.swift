import ComposableArchitecture
import SwiftUI
#if DEBUG
  import DesignSystem
  import DesignSystemGallery
#endif

/// The You-tab root view (ARCHITECTURE §4.5). **Minimal in Phase 7.4**: its only content is a
/// `#if DEBUG` **DEV** section — an eyebrow header + a design-matched card row (the Settings design
/// reference: neutral background, white rounded card, chevron affordance) that **pushes** `DevMenuView`
/// onto the You-tab navigation stack. In RELEASE the screen renders empty (Phase 10.2 fills the You tab
/// with the real CONNECTION / APPLE HEALTH / PROFILE / REMINDERS sections) and no DEV-section / dev-menu
/// symbol exists. The push uses `.navigationDestination(item:)` bound to the `@Presents var devMenu`
/// state: the You tab already sits in a `NavigationStack` (Phase 7.1) whose `SettingsPath` stack is
/// empty in 7.4, so this item-driven destination pushes/pops with the chevron with no extra nav host
/// (and no DEBUG-conditional `SettingsPath` case).
public struct SettingsFeatureView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  public init(store: StoreOf<SettingsFeature>) {
    self.store = store
  }

  public var body: some View {
    #if DEBUG
      ScrollView {
        VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
          Text("DEV")
            .font(.coachText2xs)
            .tracking(0.6)
            .foregroundStyle(.coachForegroundSubtle)
            .padding(.horizontal, CoachSpacing.spaceXs)

          // One card, two rows divided by a hairline — a normal grouped-list section. The dev menu is
          // TCA-routed; the gallery is a plain push (no state) onto the same You-tab stack because
          // `DesignSystemGalleryList` omits its own `NavigationStack`.
          VStack(spacing: 0) {
            Button {
              store.send(.devMenuTapped)
            } label: {
              DevSectionRow(title: "Dev Menu")
            }
            .buttonStyle(.plain)

            Rectangle()
              .fill(.coachBorder)
              .frame(height: 1)
              .padding(.leading, CoachSpacing.spaceMd)

            NavigationLink {
              DesignSystemGalleryList()
            } label: {
              DevSectionRow(title: "Component Gallery")
            }
            .buttonStyle(.plain)
          }
          .background(RoundedRectangle(cornerRadius: CoachRadius.md).fill(.coachSurface))
        }
        .padding(CoachSpacing.spaceMd)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(Color.coachBackground)
      .navigationTitle("Settings")
      // Push (not a sheet): SettingsFeatureView is the You-tab stack root, so this pushes onto it. No
      // wrapping `NavigationStack` — DevMenuView's own pushes (the log viewer) ride the same stack.
      .navigationDestination(item: $store.scope(state: \.devMenu, action: \.devMenu)) { devStore in
        DevMenuView(store: devStore)
      }
    #else
      // Phase 10.2 fills this with the production You-tab sections.
      Form {}
        .navigationTitle("Settings")
    #endif
  }
}

#if DEBUG
  /// A single DEV-section row (title + chevron affordance). The enclosing card supplies the surface and
  /// the hairline divider, so the row itself is just padded content — `contentShape` keeps the whole
  /// padded width (including the spacer) tappable.
  private struct DevSectionRow: View {
    let title: String

    var body: some View {
      HStack(spacing: CoachSpacing.spaceSm) {
        Text(title)
          .font(.coachTextLg)
          .foregroundStyle(.coachForeground)
        Spacer(minLength: CoachSpacing.spaceSm)
        Image(systemName: "chevron.right")
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundSubtle)
      }
      .padding(CoachSpacing.spaceMd)
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
  }
#endif
