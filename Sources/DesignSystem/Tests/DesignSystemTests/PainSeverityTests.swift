import Testing

@testable import DesignSystem

struct PainSeverityTests {
  /// Band edges of the DECISIONS #2 mapping: 0 → None, 1–3 → Mild, 4–6 → Moderate, 7–10 → Severe.
  @Test func test_severityBands_atBoundaries() {
    #expect(PainSeverity(value: 0) == .none)
    #expect(PainSeverity(value: 1) == .mild)
    #expect(PainSeverity(value: 3) == .mild)
    #expect(PainSeverity(value: 4) == .moderate)
    #expect(PainSeverity(value: 6) == .moderate)
    #expect(PainSeverity(value: 7) == .severe)
    #expect(PainSeverity(value: 10) == .severe)
  }

  /// Out-of-range input maps gracefully (the authoritative clamp lives in `CheckInComponent`).
  @Test func test_severity_outOfRange_mapsToNearestBand() {
    #expect(PainSeverity(value: -5) == .none)
    #expect(PainSeverity(value: 99) == .severe)
  }

  @Test func test_badgeText_combinesValueAndSeverity() {
    #expect(PainSeverity.badge(for: 2) == "2 · Mild")
    #expect(PainSeverity.badge(for: 0) == "0 · None")
    #expect(PainSeverity.badge(for: 8) == "8 · Severe")
  }
}
