import DomainModels
import SwiftUI

/// Internal snapshot fixtures for `SessionCard` (Phase 5.3 TASK-004) — the representative cards the
/// epic names (easy_run with a strides add-on, long_run effort-based, boxing, rest) plus a weekly
/// `PlannedSession` (hard day). Split into two device-sized catalogs so every card is fully captured.
enum SessionCardSamples {
  static let zone2 = ZoneRange(low: 143, high: 152)
  static let zone4 = ZoneRange(low: 166, high: 175)

  static let easyRun = SessionBlock(
    card: .easyRun, intensity: .easy, zoneTarget: .z2,
    durationMinLow: 35, durationMinHigh: 45, hrCapBpm: 146, cadenceSpm: 170, flags: [.appendToEasy]
  )
  static let longRun = SessionBlock(
    card: .longRun, intensity: .easy, zoneTarget: .z2,
    durationMinLow: 75, durationMinHigh: 90, hrCapBpm: 150, cadenceSpm: 168, flags: [.effortBased]
  )
  static let boxing = SessionBlock(
    card: .boxing, intensity: .quality, zoneTarget: .z4,
    durationMinLow: 30, durationMinHigh: 40, flags: [.needsGreenKnee]
  )
  static let rest = SessionBlock(
    card: .rest, intensity: .recovery, durationMinLow: 0, durationMinHigh: 0
  )
  static let weeklyHardDay = PlannedSession(
    card: .threshold, tier: .core, intensity: .quality, isHardDay: true,
    suggestedDay: .wed, zoneTarget: .z4, durationMinLow: 40, durationMinHigh: 50
  )
}

struct SessionCardRunsCatalogView: View {
  var body: some View {
    VStack(spacing: CoachSpacing.space16) {
      SessionCard(SessionCardSamples.easyRun, zoneRange: SessionCardSamples.zone2)
      SessionCard(SessionCardSamples.longRun, zoneRange: SessionCardSamples.zone2)
    }
    .padding(CoachSpacing.space16)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(CoachColor.background)
  }
}

struct SessionCardVariantsCatalogView: View {
  var body: some View {
    VStack(spacing: CoachSpacing.space16) {
      SessionCard(SessionCardSamples.boxing, zoneRange: SessionCardSamples.zone4)
      SessionCard(SessionCardSamples.rest)
      SessionCard(SessionCardSamples.weeklyHardDay, zoneRange: SessionCardSamples.zone4)
    }
    .padding(CoachSpacing.space16)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(CoachColor.background)
  }
}
