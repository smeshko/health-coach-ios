import DomainModels

/// The single zone→range lookup shared by both TodayFeature call sites — `SessionFeature.State
/// .zoneRange(for:)` (the carousel cards) and `TodaySessionMode.overrideZoneRange(override:zones:)` (the
/// forced-REST override chip) — so the two can never diverge (Phase 19.3, DECISIONS D4). Kept **internal**
/// to TodayFeature: promoting it to `DomainModels` public API is the Epic 20 SSOT consolidation, not this
/// phase's divergence fix. 2.2's `Zones` exposes named `z1…z5` fields (no `subscript(Zone)`), so the lookup
/// is an exhaustive switch.
extension DomainModels.Zones {
  /// The bpm range for a zone, resolved from this full five-zone map.
  func range(for zone: DomainModels.Zone) -> DomainModels.ZoneRange {
    switch zone {
    case .z1: return z1
    case .z2: return z2
    case .z3: return z3
    case .z4: return z4
    case .z5: return z5
    }
  }
}
