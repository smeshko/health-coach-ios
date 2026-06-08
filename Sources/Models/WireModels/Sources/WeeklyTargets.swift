import Foundation

/// The weekly training targets (`openapi.yaml` `WeeklyTargets`). `totalRunKm` is part of the
/// required set but **nullable** (`Double?`) — it decodes to `nil` when the wire sends `null`.
public struct WeeklyTargets: Codable, Sendable, Equatable {
  public var totalRunKm: Double?
  public var easyRunRatio: Double
  public var strengthSessions: Int
  public var hardDays: Int
  public var cadenceSpm: Int

  public init(
    totalRunKm: Double?,
    easyRunRatio: Double,
    strengthSessions: Int,
    hardDays: Int,
    cadenceSpm: Int
  ) {
    self.totalRunKm = totalRunKm
    self.easyRunRatio = easyRunRatio
    self.strengthSessions = strengthSessions
    self.hardDays = hardDays
    self.cadenceSpm = cadenceSpm
  }
}
