import DomainModels
import SwiftUI

/// A pure HR-zone chip — the zone label + its bpm range, color-coded cool→hot. The bpm range is passed
/// in **as data** (the feature pulls it from `ProfileRepository.zones()`); the component never reads a
/// repository (§9, D19). Color is never the sole cue — the zone label text carries the meaning too.
/// Composes the `Chip` primitive with the zone's token color (`Zone.color`/`.label`, Phase 5.1).
public struct ZoneChip: View {
  public let zone: Zone
  public let range: ZoneRange

  public init(zone: Zone, range: ZoneRange) {
    self.zone = zone
    self.range = range
  }

  public var body: some View {
    Chip(
      "\(zone.label) · \(range.low)–\(range.high) bpm",
      leading: .dot(zone.color),
      textColor: zone.color
    )
  }
}
