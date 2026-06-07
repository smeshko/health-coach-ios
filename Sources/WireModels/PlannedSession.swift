import Foundation

/// A planned weekly session (`openapi.yaml` `PlannedSession`). No `hrCapBpm`/`cadenceSpm` — those
/// are daily-only. `flags` is a **free** `[String]` (semantic typing is Phase 2.2).
public struct PlannedSession: Codable, Sendable, Equatable {
  public var card: WireEnum<WorkoutCard>
  public var tier: WireEnum<Tier>
  public var intensity: WireEnum<Intensity>
  public var isHardDay: Bool
  public var flags: [String]
  public var suggestedDay: WireEnum<Weekday>?
  public var zoneTarget: WireEnum<Zone>?
  public var durationMinLow: Int?
  public var durationMinHigh: Int?

  public init(
    card: WireEnum<WorkoutCard>,
    tier: WireEnum<Tier>,
    intensity: WireEnum<Intensity>,
    isHardDay: Bool,
    flags: [String],
    suggestedDay: WireEnum<Weekday>? = nil,
    zoneTarget: WireEnum<Zone>? = nil,
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
