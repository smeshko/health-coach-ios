import DomainModels
import Foundation

/// A prescribed session (`openapi.yaml` `SessionBlock`) — the daily `session` and its
/// `alternatives`. `flags` is a **free** `[String]` (semantic typing is Phase 2.2).
public struct SessionBlock: Codable, Sendable, Equatable {
  public var card: Card
  public var intensity: Intensity
  public var durationMinLow: Int
  public var durationMinHigh: Int
  public var flags: [String]
  public var zoneTarget: Zone?
  public var hrCapBpm: Int?
  public var cadenceSpm: Int?

  public init(
    card: Card,
    intensity: Intensity,
    durationMinLow: Int,
    durationMinHigh: Int,
    flags: [String],
    zoneTarget: Zone? = nil,
    hrCapBpm: Int? = nil,
    cadenceSpm: Int? = nil
  ) {
    self.card = card
    self.intensity = intensity
    self.durationMinLow = durationMinLow
    self.durationMinHigh = durationMinHigh
    self.flags = flags
    self.zoneTarget = zoneTarget
    self.hrCapBpm = hrCapBpm
    self.cadenceSpm = cadenceSpm
  }
}
