import DesignSystem
import SwiftUI

/// Design System → Icons. Every `Icon` registry entry as a labelled grid cell — the glyph, its role,
/// and its SF-Symbol name — by iterating the registry (`Icon.allCases`).
struct IconsGalleryPage: View {
  private let columns = [
    GridItem(.flexible(), spacing: CoachSpacing.spaceSm),
    GridItem(.flexible(), spacing: CoachSpacing.spaceSm),
  ]

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: CoachSpacing.spaceSm) {
        ForEach(Icon.allCases, id: \.self) { icon in
          VStack(spacing: CoachSpacing.spaceXs) {
            Image(systemName: icon.systemName)
              .font(.system(size: 24))
              .foregroundStyle(CoachColor.accent)
            Text(icon.role).font(CoachFont.textSm).foregroundStyle(CoachColor.foreground)
            Text(icon.systemName).font(CoachFont.textXs).foregroundStyle(CoachColor.foregroundSubtle)
          }
          .frame(maxWidth: .infinity)
          .padding(CoachSpacing.spaceSm)
          .background(RoundedRectangle(cornerRadius: CoachRadius.md).fill(CoachColor.surface))
          .overlay(RoundedRectangle(cornerRadius: CoachRadius.md).stroke(CoachColor.border, lineWidth: 1))
        }
      }
      .padding(CoachSpacing.spaceMd)
    }
    .background(CoachColor.background)
    .navigationTitle("Icons")
  }
}
