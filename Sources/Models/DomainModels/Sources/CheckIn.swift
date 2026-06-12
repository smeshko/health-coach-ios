import Foundation

/// A morning self-report check-in — the single canonical type for both the domain layer and the
/// `/sync` request member (Phase 11.3 folded the wire request twin into this). `date` is a `Date` for
/// domain consumers; its `Codable` encodes/decodes the wire `format: date` (`yyyy-MM-dd`,
/// Europe/Sofia) shape (D5), so the `/sync` JSON is unchanged.
public struct CheckIn: Equatable, Codable, Sendable {
  public var date: Date
  public var giSymptoms: Bool
  public var kneePain: Int
  public var illness: Bool

  public init(date: Date, giSymptoms: Bool, kneePain: Int, illness: Bool) {
    self.date = date
    self.giSymptoms = giSymptoms
    self.kneePain = kneePain
    self.illness = illness
  }

  private enum CodingKeys: String, CodingKey { case date, giSymptoms, kneePain, illness }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    date = try CalendarDateCoding.decode(container, forKey: .date)
    giSymptoms = try container.decode(Bool.self, forKey: .giSymptoms)
    kneePain = try container.decode(Int.self, forKey: .kneePain)
    illness = try container.decode(Bool.self, forKey: .illness)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try CalendarDateCoding.encode(date, into: &container, forKey: .date)
    try container.encode(giSymptoms, forKey: .giSymptoms)
    try container.encode(kneePain, forKey: .kneePain)
    try container.encode(illness, forKey: .illness)
  }
}
