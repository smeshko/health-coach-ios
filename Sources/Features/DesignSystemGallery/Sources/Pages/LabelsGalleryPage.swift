import DesignSystem
import DomainModels
import SwiftUI

/// Design System → Labels. The enum→label boundary (§4.4): the readiness bands and a representative
/// `label` for each domain enum, including an `.unknown(_)` sample for the open enums so the fallback
/// copy is visible. Constructs `DomainModels` cases directly (no `SampleData` import). The matrix is
/// short, so the page is its own snapshot section (`LabelsSection`).
struct LabelsGalleryPage: View {
  var body: some View {
    GalleryScaffold(title: "Labels") {
      LabelsSection()
    }
  }
}

/// The device-fitting enum→label matrix — snapshotted directly (not via the scrolling page).
struct LabelsSection: View {
  var body: some View {
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
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(CoachSpacing.spaceMd)
    .background(CoachColor.background)
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
