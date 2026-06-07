import DomainModels
import SwiftUI

/// An internal swatch/label catalog — the snapshot fixture for Phase 5.1 (and a preview), **not** a
/// product screen. It lays out the color swatches (each with its label), the type scale, the
/// spacing/radii samples, and the enum→label mappings (incl. an `.unknown(_)` sample for the open
/// enums). It constructs `DomainModels` enum cases directly (no `SampleData` import; §4.4).
struct TokenCatalogView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.space24) {
        colorSection
        typeSection
        spacingSection
        enumSection
      }
      .padding(CoachSpacing.space16)
    }
    .background(CoachColor.background)
  }

  private var colorSection: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space8) {
      Text("Colors").font(CoachFont.screenTitle).foregroundStyle(CoachColor.foreground)
      swatchRow("Green", CoachColor.green)
      swatchRow("Amber", CoachColor.amber)
      swatchRow("Red", CoachColor.red)
      swatchRow("Zone 1", CoachColor.z1)
      swatchRow("Zone 3", CoachColor.z3)
      swatchRow("Zone 5", CoachColor.z5)
      swatchRow("Easy", CoachColor.easy)
      swatchRow("Quality", CoachColor.quality)
      swatchRow("Recovery", CoachColor.recovery)
      swatchRow("Accent", CoachColor.accent)
      swatchRow("Surface", CoachColor.surface)
      swatchRow("Border", CoachColor.border)
    }
  }

  private func swatchRow(_ name: String, _ color: Color) -> some View {
    HStack(spacing: CoachSpacing.space12) {
      RoundedRectangle(cornerRadius: CoachRadius.sm)
        .fill(color)
        .frame(width: 40, height: 24)
        .overlay(RoundedRectangle(cornerRadius: CoachRadius.sm).stroke(CoachColor.border))
      Text(name).font(CoachFont.secondaryMeta).foregroundStyle(CoachColor.foreground)
    }
  }

  private var typeSection: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space6) {
      Text("Typography").font(CoachFont.screenTitle).foregroundStyle(CoachColor.foreground)
      Text("84").font(CoachFont.displayNumerals).foregroundStyle(CoachColor.foreground)
      Text("Page hero").font(CoachFont.pageHero).foregroundStyle(CoachColor.foreground)
      Text("Card headline").font(CoachFont.cardHeadline).foregroundStyle(CoachColor.foreground)
      Text("Body / narrative text sample").font(CoachFont.body).foregroundStyle(CoachColor.foreground)
      Text("Secondary meta").font(CoachFont.secondaryMeta).foregroundStyle(CoachColor.foregroundMuted)
      Text("EYEBROW").font(CoachFont.eyebrow).tracking(1).foregroundStyle(CoachColor.foregroundSubtle)
    }
  }

  private var spacingSection: some View {
    let widths = [CoachSpacing.space4, CoachSpacing.space8, CoachSpacing.space16, CoachSpacing.space24]
    let radii = [CoachRadius.sm, CoachRadius.md, CoachRadius.card]
    return VStack(alignment: .leading, spacing: CoachSpacing.space6) {
      Text("Spacing & Radii").font(CoachFont.screenTitle).foregroundStyle(CoachColor.foreground)
      HStack(spacing: CoachSpacing.space8) {
        ForEach(widths, id: \.self) { size in
          RoundedRectangle(cornerRadius: CoachRadius.sm).fill(CoachColor.accent).frame(width: size, height: 24)
        }
      }
      HStack(spacing: CoachSpacing.space12) {
        ForEach(radii, id: \.self) { radius in
          RoundedRectangle(cornerRadius: radius).fill(CoachColor.surfaceRaised)
            .frame(width: 48, height: 48)
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(CoachColor.border))
        }
      }
    }
  }

  private var enumSection: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space6) {
      Text("Labels").font(CoachFont.screenTitle).foregroundStyle(CoachColor.foreground)
      bandRow(.green)
      bandRow(.amber)
      bandRow(.red)
      labelRow("Card", Card.easyRun.label)
      labelRow("Zone", Zone.z3.label)
      labelRow("Intensity", Intensity.quality.label)
      labelRow("DayType", DayType.hard.label)
      labelRow("Narrative", NarrativeType.summary.label)
      labelRow("Tier", Tier.core.label)
      labelRow("Weekday", Weekday.mon.label)
      labelRow("Flag (known)", Flag.qualityDay.label)
      labelRow("Flag (unknown)", Flag.unknown("brand_new_flag").label)
      labelRow("Safety (unknown)", SafetyReason.unknown("odd_signal").label)
      labelRow("Penalty (unknown)", PenaltyFactor.unknown("late_caffeine").label)
      labelRow("Error", ErrorDisplay.upstreamTimeout.label)
    }
  }

  private func bandRow(_ band: ReadinessBand) -> some View {
    HStack(spacing: CoachSpacing.space8) {
      Image(systemName: band.iconName).foregroundStyle(band.color)
      Text(band.label).font(CoachFont.secondaryMeta).foregroundStyle(band.color)
    }
  }

  private func labelRow(_ key: String, _ value: String) -> some View {
    HStack(spacing: CoachSpacing.space8) {
      Text(key).font(CoachFont.eyebrow).foregroundStyle(CoachColor.foregroundSubtle)
      Text(value).font(CoachFont.secondaryMeta).foregroundStyle(CoachColor.foreground)
    }
  }
}
