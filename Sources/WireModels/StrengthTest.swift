import Foundation

/// A periodic strength benchmark (`openapi.yaml` `StrengthTest`). `date` is a calendar `date`.
public struct StrengthTest: Codable, Sendable, Equatable {
  public var date: WireCalendarDate
  public var maxPushups: Int
  public var maxPullups: Int

  public init(date: WireCalendarDate, maxPushups: Int, maxPullups: Int) {
    self.date = date
    self.maxPushups = maxPushups
    self.maxPullups = maxPullups
  }
}
