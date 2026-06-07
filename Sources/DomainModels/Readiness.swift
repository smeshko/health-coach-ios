import Foundation

/// Readiness scoring for the daily brief.
public struct Readiness: Equatable, Sendable {
  public var score: Int
  public var band: ReadinessBand
  /// Penalties — guaranteed non-optional, defaults to empty.
  public var penalties: [ReadinessPenalty]

  public init(score: Int, band: ReadinessBand, penalties: [ReadinessPenalty] = []) {
    self.score = score
    self.band = band
    self.penalties = penalties
  }
}

/// A single readiness penalty (typed factor).
public struct ReadinessPenalty: Equatable, Sendable {
  public var factor: PenaltyFactor
  public var points: Int

  public init(factor: PenaltyFactor, points: Int) {
    self.factor = factor
    self.points = points
  }
}

/// The safety gate. A tripped gate is a normal brief, not an error.
public struct SafetyGate: Equatable, Sendable {
  public var triggered: Bool
  /// Typed reasons — guaranteed non-optional, defaults to empty.
  public var reasons: [SafetyReason]
  public var overrideTo: Card?

  public init(triggered: Bool, reasons: [SafetyReason] = [], overrideTo: Card? = nil) {
    self.triggered = triggered
    self.reasons = reasons
    self.overrideTo = overrideTo
  }
}
