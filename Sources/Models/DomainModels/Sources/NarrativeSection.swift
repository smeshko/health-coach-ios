import Foundation

/// A rendered narrative block, shown verbatim to the athlete (ARCHITECTURE principle #1).
public struct NarrativeSection: Equatable, Sendable {
  public var type: NarrativeType
  public var heading: String
  public var body: String

  public init(type: NarrativeType, heading: String, body: String) {
    self.type = type
    self.heading = heading
    self.body = body
  }
}
