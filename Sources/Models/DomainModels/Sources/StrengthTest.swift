import Foundation

/// A periodic strength benchmark — the single canonical type for both the domain layer and the
/// `/sync` request member (Phase 11.3 folded the wire `StrengthTest` twin into this; see ``CheckIn``).
/// `date` is a `Date`; its `Codable` encodes/decodes the wire `format: date` (`yyyy-MM-dd`,
/// Europe/Sofia) shape (D5).
public struct StrengthTest: Equatable, Codable, Sendable {
  public var date: Date
  public var maxPushups: Int
  public var maxPullups: Int

  public init(date: Date, maxPushups: Int, maxPullups: Int) {
    self.date = date
    self.maxPushups = maxPushups
    self.maxPullups = maxPullups
  }

  private enum CodingKeys: String, CodingKey { case date, maxPushups, maxPullups }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    date = try CalendarDateCoding.decode(container, forKey: .date)
    maxPushups = try container.decode(Int.self, forKey: .maxPushups)
    maxPullups = try container.decode(Int.self, forKey: .maxPullups)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try CalendarDateCoding.encode(date, into: &container, forKey: .date)
    try container.encode(maxPushups, forKey: .maxPushups)
    try container.encode(maxPullups, forKey: .maxPullups)
  }
}
