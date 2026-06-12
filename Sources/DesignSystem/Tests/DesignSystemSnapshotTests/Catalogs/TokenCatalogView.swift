import DesignSystem
import DomainModels
import SwiftUI

/// A swatch/label catalog — the snapshot fixture for the tokens + enum→label boundary, **not** a product
/// screen. It lays out the color swatches (each with its label), the type scale, the spacing/radii
/// samples, and the enum→label mappings (incl. an `.unknown(_)` sample for the open enums). It
/// constructs `DomainModels` enum cases directly (no `SampleData` import; §4.4). Lives in the
/// snapshot-test target (only `TokenCatalogSnapshotTests` renders it).
struct TokenCatalogView: View {
  // Sample values for the spacing/radii rows — data, not views.
  private let spacingWidths: [CGFloat] = [
    CoachSpacing.space2xs, CoachSpacing.spaceXs, CoachSpacing.spaceMd, CoachSpacing.spaceLg,
  ]
  private let radiusSamples: [CGFloat] = [CoachRadius.sm, CoachRadius.md, CoachRadius.card]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
        // Colors.
        VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
          Text("Colors").font(CoachFont.text2xl).foregroundStyle(CoachColor.foreground)
          swatchRow("Positive", CoachColor.positive)
          swatchRow("Warning", CoachColor.warning)
          swatchRow("Negative", CoachColor.negative)
          swatchRow("Info", CoachColor.info)
          swatchRow("Zone 1", CoachColor.z1)
          swatchRow("Zone 3", CoachColor.z3)
          swatchRow("Zone 5", CoachColor.z5)
          swatchRow("Accent", CoachColor.accent)
          swatchRow("Surface", CoachColor.surface)
          swatchRow("Border", CoachColor.border)
        }

        // Typography.
        VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
          Text("Typography").font(CoachFont.text2xl).foregroundStyle(CoachColor.foreground)
          Text("84").font(CoachFont.textDisplay).foregroundStyle(CoachColor.foreground)
          Text("Page hero").font(CoachFont.text3xl).foregroundStyle(CoachColor.foreground)
          Text("Card headline").font(CoachFont.textLg).foregroundStyle(CoachColor.foreground)
          Text("Body / narrative text sample").font(CoachFont.textMd).foregroundStyle(CoachColor.foreground)
          Text("Secondary meta").font(CoachFont.textSm).foregroundStyle(CoachColor.foregroundMuted)
          Text("EYEBROW").font(CoachFont.text2xs).tracking(1).foregroundStyle(CoachColor.foregroundSubtle)
        }

        // Spacing & Radii.
        VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
          Text("Spacing & Radii").font(CoachFont.text2xl).foregroundStyle(CoachColor.foreground)
          HStack(spacing: CoachSpacing.spaceXs) {
            ForEach(spacingWidths, id: \.self) { size in
              RoundedRectangle(cornerRadius: CoachRadius.sm).fill(CoachColor.accent).frame(width: size, height: 24)
            }
          }
          HStack(spacing: CoachSpacing.spaceSm) {
            ForEach(radiusSamples, id: \.self) { radius in
              RoundedRectangle(cornerRadius: radius).fill(CoachColor.surfaceRaised)
                .frame(width: 48, height: 48)
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(CoachColor.border))
            }
          }
        }

        // Labels (enum→label boundary).
        VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
          Text("Labels").font(CoachFont.text2xl).foregroundStyle(CoachColor.foreground)
          bandRow(.green)
          bandRow(.amber)
          bandRow(.red)
          labelRow("Card", Card.easyRun.label)
          labelRow("Intensity", Intensity.quality.label)
          labelRow("DayType", DayType.hard.label)
          labelRow("Tier", Tier.core.label)
          labelRow("Weekday", Weekday.mon.label)
          labelRow("Flag (known)", Flag.qualityDay.label)
          labelRow("Flag (unknown)", Flag.unknown("brand_new_flag").label)
          labelRow("Safety (unknown)", SafetyReason.unknown("odd_signal").label)
          labelRow("Penalty (unknown)", PenaltyFactor.unknown("late_caffeine").label)
          labelRow("Error", ErrorDisplay.upstreamTimeout.label)
        }
      }
      .padding(CoachSpacing.spaceMd)
    }
    .background(CoachColor.background)
  }

  private func swatchRow(_ name: String, _ color: Color) -> some View {
    HStack(spacing: CoachSpacing.spaceSm) {
      RoundedRectangle(cornerRadius: CoachRadius.sm)
        .fill(color)
        .frame(width: 40, height: 24)
        .overlay(RoundedRectangle(cornerRadius: CoachRadius.sm).stroke(CoachColor.border))
      Text(name).font(CoachFont.textSm).foregroundStyle(CoachColor.foreground)
    }
  }

  private func bandRow(_ band: ReadinessBand) -> some View {
    HStack(spacing: CoachSpacing.spaceXs) {
      Text(band.label).font(CoachFont.textSm).foregroundStyle(band.color)
    }
  }

  private func labelRow(_ key: String, _ value: String) -> some View {
    HStack(spacing: CoachSpacing.spaceXs) {
      Text(key).font(CoachFont.text2xs).foregroundStyle(CoachColor.foregroundSubtle)
      Text(value).font(CoachFont.textSm).foregroundStyle(CoachColor.foreground)
    }
  }
}
