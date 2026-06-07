import DomainModels
import SwiftUI

/// A small prominent tag for the nutrition `DayType` (PRD §12.3) — consumed by the nutrition surfaces
/// (Phase 5.4), shipped here as a tiny pure view in the DesignSystem vocabulary. No per-day-type color
/// token exists (label-only mapping, Phase 5.1), so prominence comes from the `Pill` shell + the label.
public struct DayTypeTag: View {
  public let dayType: DayType

  public init(dayType: DayType) {
    self.dayType = dayType
  }

  public var body: some View {
    Pill(dayType.label, tone: .accent)
  }
}
