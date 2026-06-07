import DesignSystem
import SwiftUI

/// Design System → Colors. Every `CoachColor` token as a named swatch, grouped (readiness / zones /
/// intensities / accent / semantic / surfaces). The OS resolves each color in the current scheme, so
/// the page is reviewable in both light and dark. A single source list drives it.
struct ColorsGalleryPage: View {
  private struct Group: Identifiable {
    var id: String { title }
    let title: String
    let swatches: [(name: String, color: Color)]
  }

  private let swatchSize: CGFloat = 44

  private let groups: [Group] = [
    Group(title: "Readiness", swatches: [
      ("green", CoachColor.green), ("amber", CoachColor.amber), ("red", CoachColor.red),
    ]),
    Group(title: "Zones", swatches: [
      ("z1", CoachColor.z1), ("z2", CoachColor.z2), ("z3", CoachColor.z3),
      ("z4", CoachColor.z4), ("z5", CoachColor.z5),
    ]),
    Group(title: "Intensity", swatches: [
      ("easy", CoachColor.easy), ("quality", CoachColor.quality), ("recovery", CoachColor.recovery),
    ]),
    Group(title: "Accent", swatches: [
      ("accent", CoachColor.accent), ("accentSoft", CoachColor.accentSoft),
      ("onAccent", CoachColor.onAccent), ("onAccentMuted", CoachColor.onAccentMuted),
      ("onAccentSoft", CoachColor.onAccentSoft), ("tabSelected", CoachColor.tabSelected),
    ]),
    Group(title: "Semantic", swatches: [
      ("warning", CoachColor.warning), ("warningSoft", CoachColor.warningSoft),
      ("negative", CoachColor.negative), ("negativeSoft", CoachColor.negativeSoft),
      ("positive", CoachColor.positive), ("positiveSoft", CoachColor.positiveSoft),
    ]),
    Group(title: "Surfaces & text", swatches: [
      ("background", CoachColor.background), ("surface", CoachColor.surface),
      ("surfaceRaised", CoachColor.surfaceRaised), ("surfaceGlass", CoachColor.surfaceGlass),
      ("border", CoachColor.border), ("shadow", CoachColor.shadow),
      ("foreground", CoachColor.foreground), ("foregroundMuted", CoachColor.foregroundMuted),
      ("foregroundSubtle", CoachColor.foregroundSubtle),
    ]),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.space16) {
        ForEach(groups) { group in
          VStack(alignment: .leading, spacing: CoachSpacing.space8) {
            Text(group.title).font(CoachFont.eyebrow).foregroundStyle(CoachColor.foregroundSubtle)
            ForEach(group.swatches, id: \.name) { swatch in
              HStack(spacing: CoachSpacing.space12) {
                RoundedRectangle(cornerRadius: CoachRadius.sm)
                  .fill(swatch.color)
                  .frame(width: swatchSize, height: swatchSize)
                  .overlay(RoundedRectangle(cornerRadius: CoachRadius.sm).stroke(CoachColor.border, lineWidth: 1))
                Text(swatch.name).font(CoachFont.body).foregroundStyle(CoachColor.foreground)
              }
            }
          }
        }
      }
      .padding(CoachSpacing.space16)
    }
    .background(CoachColor.background)
    .navigationTitle("Colors")
  }
}
