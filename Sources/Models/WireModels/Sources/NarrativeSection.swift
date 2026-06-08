import Foundation

/// One rendered narrative block (`openapi.yaml` `NarrativeSection`). Rendered verbatim downstream
/// (ARCHITECTURE principle #1) — no interpretation here.
public struct NarrativeSection: Codable, Sendable, Equatable {
  public var type: WireEnum<NarrativeType>
  public var heading: String
  public var body: String

  public init(type: WireEnum<NarrativeType>, heading: String, body: String) {
    self.type = type
    self.heading = heading
    self.body = body
  }
}
