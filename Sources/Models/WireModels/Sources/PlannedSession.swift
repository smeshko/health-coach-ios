import DomainModels
import Foundation

/// A planned weekly session (`openapi.yaml` `PlannedSession`). No `hrCapBpm`/`cadenceSpm` — those
/// are daily-only. `flags` is a **free** `[String]` (semantic typing is Phase 2.2).
public struct PlannedSession: Codable, Sendable, Equatable {
  public var card: Card
  public var tier: Tier
  public var intensity: Intensity
  public var isHardDay: Bool
  public var flags: [String]
  public var suggestedDay: Weekday?
  public var zoneTarget: Zone?
  public var durationMinLow: Int?
  public var durationMinHigh: Int?

  public init(
    card: Card,
    tier: Tier,
    intensity: Intensity,
    isHardDay: Bool,
    flags: [String],
    suggestedDay: Weekday? = nil,
    zoneTarget: Zone? = nil,
    durationMinLow: Int? = nil,
    durationMinHigh: Int? = nil
  ) {
    self.card = card
    self.tier = tier
    self.intensity = intensity
    self.isHardDay = isHardDay
    self.flags = flags
    self.suggestedDay = suggestedDay
    self.zoneTarget = zoneTarget
    self.durationMinLow = durationMinLow
    self.durationMinHigh = durationMinHigh
  }
}
