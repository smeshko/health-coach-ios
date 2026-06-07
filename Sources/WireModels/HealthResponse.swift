import Foundation

/// The `/health` response (`openapi.yaml` `HealthResponse`). `serverTime` is a `date-time`.
public struct HealthResponse: Codable, Sendable, Equatable {
  public var status: String
  public var serverTime: Date

  public init(status: String, serverTime: Date) {
    self.status = status
    self.serverTime = serverTime
  }
}
