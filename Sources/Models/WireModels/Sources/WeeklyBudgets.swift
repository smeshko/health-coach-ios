import Foundation

/// The weekly training budgets (`openapi.yaml` `WeeklyBudgets`).
public struct WeeklyBudgets: Codable, Sendable, Equatable {
  public var hardDays: Int
  public var strengthSessions: Int
  public var longRunKm: Double?
  public var deload: Bool

  public init(hardDays: Int, strengthSessions: Int, longRunKm: Double? = nil, deload: Bool) {
    self.hardDays = hardDays
    self.strengthSessions = strengthSessions
    self.longRunKm = longRunKm
    self.deload = deload
  }
}
