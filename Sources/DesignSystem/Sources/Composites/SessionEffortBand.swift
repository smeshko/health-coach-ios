import DomainModels

/// The derived 1–10 **effort band** for a session shown on the effort scale (a strength / no-`zoneTarget`
/// session). This is **presentation derivation, not health math**: it maps the user's zone→RPE table
/// (Z1→1–3, Z2→3–4, Z3→5–6, Z4→7–8, Z5→9–10), falling back to the session's `intensity` when there is no
/// zone (quality → a high band, recovery → a low band, easy → a low-moderate band). The band drives only
/// the highlighted segments of `SegmentedBar.range`; no numeric "RPE N" copy is ever rendered from it. If
/// the API later carries an explicit RPE, this is replaced by wire data (a flagged 2.2/openapi follow-up).
func effortBand(for block: SessionBlock) -> ClosedRange<Int> {
  effortBand(zoneTarget: block.zoneTarget, intensity: block.intensity)
}

/// The shared zone/intensity → 1–10 band derivation — one map, two callers: the daily `SessionBlock`
/// (above) and the weekly `PlannedSession` (Phase 9.2's `WeeklySessionRow`). Both carry a
/// `zoneTarget: Zone?` + `intensity`, so the weekly row feeds these fields directly rather than
/// authoring a second map (PLAN 9.2 / TASK-001).
func effortBand(zoneTarget: Zone?, intensity: Intensity) -> ClosedRange<Int> {
  if let zoneTarget {
    switch zoneTarget {
    case .z1: return 1 ... 3
    case .z2: return 3 ... 4
    case .z3: return 5 ... 6
    case .z4: return 7 ... 8
    case .z5: return 9 ... 10
    }
  }
  switch intensity {
  case .quality: return 7 ... 8
  case .easy: return 3 ... 4
  case .recovery: return 2 ... 3
  }
}
