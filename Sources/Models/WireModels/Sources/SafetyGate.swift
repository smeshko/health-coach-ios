import Foundation

/// The safety gate on a daily brief (`openapi.yaml` `SafetyGate`). A tripped gate
/// (`triggered == true`, an `overrideTo` card, empty `alternatives`) is a normal `200` brief, not
/// an error. `reasons` is a **free** `[String]` (semantic typing is Phase 2.2).
public struct SafetyGate: Codable, Sendable, Equatable {
  public var triggered: Bool
  public var reasons: [String]
  public var overrideTo: WireEnum<WorkoutCard>?

  public init(triggered: Bool, reasons: [String], overrideTo: WireEnum<WorkoutCard>? = nil) {
    self.triggered = triggered
    self.reasons = reasons
    self.overrideTo = overrideTo
  }
}
