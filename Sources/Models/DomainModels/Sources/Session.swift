import Foundation

/// A prescribed daily session (the daily `session` and its `alternatives`).
public struct SessionBlock: Equatable, Codable, Sendable {
  public var card: Card
  public var intensity: Intensity
  public var zoneTarget: Zone?
  public var durationMinLow: Int
  public var durationMinHigh: Int
  public var hrCapBpm: Int?
  public var cadenceSpm: Int?
  /// Typed flags — guaranteed non-optional, defaults to empty.
  public var flags: [Flag]

  public init(
    card: Card,
    intensity: Intensity,
    zoneTarget: Zone? = nil,
    durationMinLow: Int,
    durationMinHigh: Int,
    hrCapBpm: Int? = nil,
    cadenceSpm: Int? = nil,
    flags: [Flag] = []
  ) {
    self.card = card
    self.intensity = intensity
    self.zoneTarget = zoneTarget
    self.durationMinLow = durationMinLow
    self.durationMinHigh = durationMinHigh
    self.hrCapBpm = hrCapBpm
    self.cadenceSpm = cadenceSpm
    self.flags = flags
  }

  /// The prescribed duration window, in minutes. Guards against an inverted server brief
  /// (`durationMinLow > durationMinHigh`): a raw `low ... high` would trap on the `ClosedRange`
  /// precondition at render time, so clamp to `min ... max` — a malformed/inverted brief renders a
  /// (reversed-but-valid) window instead of crashing; invisible for all well-formed data
  /// (Phase 11.6 / audit production finding 3).
  public var durationRange: ClosedRange<Int> {
    min(durationMinLow, durationMinHigh) ... max(durationMinLow, durationMinHigh)
  }

  /// Whether this session is a rest day.
  public var isRest: Bool {
    card == .rest
  }
}

/// A planned weekly session (no `hrCapBpm`/`cadenceSpm` — those are daily-only).
public struct PlannedSession: Equatable, Codable, Sendable {
  public var card: Card
  public var tier: Tier
  public var intensity: Intensity
  public var isHardDay: Bool
  public var suggestedDay: Weekday?
  public var zoneTarget: Zone?
  public var durationMinLow: Int?
  public var durationMinHigh: Int?
  /// Typed flags — guaranteed non-optional, defaults to empty.
  public var flags: [Flag]

  public init(
    card: Card,
    tier: Tier,
    intensity: Intensity,
    isHardDay: Bool,
    suggestedDay: Weekday? = nil,
    zoneTarget: Zone? = nil,
    durationMinLow: Int? = nil,
    durationMinHigh: Int? = nil,
    flags: [Flag] = []
  ) {
    self.card = card
    self.tier = tier
    self.intensity = intensity
    self.isHardDay = isHardDay
    self.suggestedDay = suggestedDay
    self.zoneTarget = zoneTarget
    self.durationMinLow = durationMinLow
    self.durationMinHigh = durationMinHigh
    self.flags = flags
  }
}
