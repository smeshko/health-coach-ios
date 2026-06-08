import DesignSystem
import SwiftUI

/// Design System → Spacing & Radii. Mirrors the Spacing & Radii reference: the eight-step t-shirt
/// spacing scale as proportional bars (bar width = the token's value) beside its name + px, and the
/// four corner radii as outlined samples. Single source lists drive both groups.
struct SpacingGalleryPage: View {
  private struct Step: Identifiable {
    var id: String { name }
    let name: String
    let value: CGFloat
  }

  private struct Radius: Identifiable {
    var id: String { name }
    let name: String
    let value: CGFloat
    let isPill: Bool
  }

  private let barHeight: CGFloat = 14
  private let nameColumn: CGFloat = 104

  private let spacings: [Step] = [
    Step(name: "space-2xs", value: CoachSpacing.space2xs),
    Step(name: "space-xs", value: CoachSpacing.spaceXs),
    Step(name: "space-sm", value: CoachSpacing.spaceSm),
    Step(name: "space-md", value: CoachSpacing.spaceMd),
    Step(name: "space-lg", value: CoachSpacing.spaceLg),
    Step(name: "space-xl", value: CoachSpacing.spaceXl),
    Step(name: "space-2xl", value: CoachSpacing.space2xl),
    Step(name: "space-3xl", value: CoachSpacing.space3xl),
  ]

  private let radii: [Radius] = [
    Radius(name: "radius-sm", value: CoachRadius.sm, isPill: false),
    Radius(name: "radius-md", value: CoachRadius.md, isPill: false),
    Radius(name: "radius-card", value: CoachRadius.card, isPill: false),
    Radius(name: "radius-pill", value: CoachRadius.pill, isPill: true),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
        Text(
          "Eight steps on a t-shirt scale (space-2xs … space-3xl), bound to a token — no raw pixel "
            + "spacing. Four corner radii; pills use 999."
        )
        .font(CoachFont.textMd)
        .foregroundStyle(CoachColor.foregroundMuted)

        VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
          eyebrow("Spacing scale")
          ForEach(spacings) { spacingRow($0) }
        }

        VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
          eyebrow("Corner radii")
          HStack(alignment: .top, spacing: CoachSpacing.spaceSm) {
            ForEach(radii) { radiusSample($0) }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(CoachSpacing.spaceMd)
    }
    .background(CoachColor.background)
    .navigationTitle("Spacing & Radii")
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text).font(CoachFont.text2xs).tracking(1).foregroundStyle(CoachColor.foregroundSubtle)
  }

  private func spacingRow(_ step: Step) -> some View {
    HStack(spacing: CoachSpacing.spaceMd) {
      RoundedRectangle(cornerRadius: CoachRadius.sm)
        .fill(CoachColor.accent)
        .frame(width: step.value, height: barHeight)
        .frame(width: CoachSpacing.space3xl, alignment: .leading)
      Text(step.name)
        .font(CoachFont.textLg)
        .foregroundStyle(CoachColor.foreground)
        .frame(width: nameColumn, alignment: .leading)
      Text("\(Int(step.value))px")
        .font(CoachFont.textMd)
        .foregroundStyle(CoachColor.foregroundSubtle)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func radiusSample(_ radius: Radius) -> some View {
    VStack(spacing: CoachSpacing.spaceXs) {
      RoundedRectangle(cornerRadius: radius.value)
        .stroke(CoachColor.border, lineWidth: 1)
        .frame(width: radius.isPill ? 96 : 72, height: 72)
      VStack(spacing: 0) {
        Text(radius.name).font(CoachFont.textXs).foregroundStyle(CoachColor.foregroundMuted)
        Text("\(Int(radius.value))").font(CoachFont.textXs).foregroundStyle(CoachColor.foregroundSubtle)
      }
    }
  }
}
