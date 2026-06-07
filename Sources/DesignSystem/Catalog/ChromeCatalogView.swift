import SwiftUI

/// Internal snapshot fixture for the chrome/nav primitives (Phase 5.2 TASK-003). The full-screen
/// state composites (`RestDay`, `MessageState`) are snapshotted directly.
struct ChromeCatalogView: View {
  var body: some View {
    VStack(spacing: CoachSpacing.space24) {
      StatusBar()
      TabBar(selection: .constant(.today))
      TabBar(selection: .constant(.trends))
      Spacer()
    }
    .padding(.vertical, CoachSpacing.space24)
    .background(CoachColor.background)
  }
}
