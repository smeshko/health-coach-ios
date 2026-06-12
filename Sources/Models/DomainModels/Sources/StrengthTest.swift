import Foundation

/// A periodic strength benchmark (domain twin of the wire `StrengthTest` request member).
///
/// Added in Phase 2.3 as the domain peer of `StrengthTestRecord` (see ``CheckIn``). Plain
/// `Equatable`/`Sendable`, no `Codable`/GRDB.
public struct StrengthTest: Equatable, Codable, Sendable {
  public var date: Date
  public var maxPushups: Int
  public var maxPullups: Int

  public init(date: Date, maxPushups: Int, maxPullups: Int) {
    self.date = date
    self.maxPushups = maxPushups
    self.maxPullups = maxPullups
  }
}
