import DomainModels
import SwiftUI

/// Internal snapshot fixture for the session vocabulary components (Phase 5.3 TASK-001) — ZoneChip,
/// FlagBadge (incl. `.unknown`), DayTypeTag. Constructs `DomainModels` values directly.
struct SessionComponentsCatalogView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space24) {
      group("ZoneChip") {
        ZoneChip(zone: .z2, range: ZoneRange(low: 143, high: 152))
        ZoneChip(zone: .z4, range: ZoneRange(low: 166, high: 175))
      }
      group("FlagBadge") {
        FlagBadge(flag: .effortBased)
        FlagBadge(flag: .needsGreenKnee)
        FlagBadge(flag: .unknown("brand_new_flag"))
      }
      group("DayTypeTag") {
        DayTypeTag(dayType: .hard)
        DayTypeTag(dayType: .moderate)
        DayTypeTag(dayType: .rest)
      }
    }
    .padding(CoachSpacing.space16)
    .background(CoachColor.background)
  }

  private func group(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space8) {
      Text(title).font(CoachFont.eyebrow).foregroundStyle(CoachColor.foregroundSubtle)
      HStack(spacing: CoachSpacing.space8) { content() }
    }
  }
}
