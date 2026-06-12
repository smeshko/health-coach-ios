import DomainModels
import Foundation

/// Readiness scoring for the daily brief (`openapi.yaml` `Readiness`).
public struct Readiness: Codable, Sendable, Equatable {
  public var score: Int
  public var band: ReadinessBand
  public var penalties: [ReadinessPenalty]

  public init(score: Int, band: ReadinessBand, penalties: [ReadinessPenalty]) {
    self.score = score
    self.band = band
    self.penalties = penalties
  }
}

/// A single readiness penalty (`openapi.yaml` `ReadinessPenalty`). `factor` is a **free** string
/// (semantic typing is Phase 2.2).
public struct ReadinessPenalty: Codable, Sendable, Equatable {
  public var factor: String
  public var points: Int

  public init(factor: String, points: Int) {
    self.factor = factor
    self.points = points
  }
}
