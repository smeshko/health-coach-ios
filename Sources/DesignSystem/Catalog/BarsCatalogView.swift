import SwiftUI

/// Internal snapshot fixture for the bar composites + the prehab row (Phase 5.2 TASK-002).
struct BarsCatalogView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space24) {
      group("ZoneBar") {
        ZoneBar(target: 1)
        ZoneBar(target: 3)
        ZoneBar(target: 5)
      }
      group("ReadinessBar") {
        ReadinessBar(score: 20)
        ReadinessBar(score: 60)
        ReadinessBar(score: 88)
      }
      VStack(alignment: .leading, spacing: CoachSpacing.space8) {
        Text("PrehabAddon").font(CoachFont.eyebrow).foregroundStyle(CoachColor.foregroundSubtle)
        PrehabAddon(title: "Foot prehab · 5 min", subtitle: "Quick add-on for flat feet")
      }
    }
    .padding(CoachSpacing.space16)
    .background(CoachColor.background)
  }

  private func group(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space12) {
      Text(title).font(CoachFont.eyebrow).foregroundStyle(CoachColor.foregroundSubtle)
      content()
    }
  }
}
