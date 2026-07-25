import DesignSystem
import SwiftUI

/// The shared widget eyebrow line ("TODAY'S SESSION" / "TODAY'S FUEL") — the skeleton's uppercase
/// tracked caption, reused by every home-screen widget layout.
struct WidgetEyebrow: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.coachText2xs)
      .tracking(1)
      .foregroundStyle(.coachForegroundSubtle)
  }
}
