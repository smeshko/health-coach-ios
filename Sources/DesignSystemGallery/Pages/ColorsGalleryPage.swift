import DesignSystem
import SwiftUI

/// Design System → Colors. Every `CoachColor` token as a named swatch (resolved by the OS in the
/// current scheme; reviewable light + dark). Content lands in TASK-002.
struct ColorsGalleryPage: View {
  var body: some View {
    Text("Colors").navigationTitle("Colors")
  }
}
