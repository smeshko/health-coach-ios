import DesignSystem
import SwiftUI

/// A shared scaffold for the component subpages — a scrolling, token-padded column on the app
/// background with a navigation title. Each state group is labelled with `stateLabel(_:)`.
struct GalleryScaffold<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.space16) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(CoachSpacing.space16)
    }
    .background(CoachColor.background)
    .navigationTitle(title)
  }
}

/// A small caption above a state in a component subpage.
func stateLabel(_ text: String) -> some View {
  Text(text).font(CoachFont.eyebrow).foregroundStyle(CoachColor.foregroundSubtle)
}
