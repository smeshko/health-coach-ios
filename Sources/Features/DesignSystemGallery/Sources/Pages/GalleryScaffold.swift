import DesignSystem
import SwiftUI

/// A shared scaffold for the component subpages — a scrolling, token-padded column on the app
/// background with a navigation title. Each state group is labelled with `stateLabel(_:)`.
struct GalleryScaffold<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(CoachSpacing.spaceMd)
    }
    .background(.coachBackground)
    .navigationTitle(title)
  }
}

/// A small caption above a state in a component subpage.
func stateLabel(_ text: String) -> some View {
  Text(text).font(.coachText2xs).foregroundStyle(.coachForegroundSubtle)
}

/// Wraps content in a surface card (card radius + `spaceLg` padding) so a component shows on its real
/// product surface rather than the gallery's sunken background — used for the bar/chart pages, where the
/// pale track needs a surface behind it.
func galleryCard(@ViewBuilder _ content: () -> some View) -> some View {
  content()
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous).fill(.coachSurface)
    )
}
