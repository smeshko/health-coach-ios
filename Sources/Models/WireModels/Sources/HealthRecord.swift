import Foundation

/// A single HealthKit sample synced to the backend (`openapi.yaml` `HealthRecord`).
///
/// Allows both the quantity shape (`value` + `unit`) and the category shape (`category`) with no
/// "exactly one of" validator — every sample-shape field is optional. `start`/`end` are
/// `date-time`; `metadata` is a free `additionalProperties` map of string values.
public struct HealthRecord: Codable, Sendable, Equatable {
  public var uuid: String
  public var type: WireEnum<RecordType>
  public var start: Date
  public var end: Date
  public var value: Double?
  public var unit: String?
  public var category: String?
  public var source: String?
  public var metadata: [String: String]?

  public init(
    uuid: String,
    type: WireEnum<RecordType>,
    start: Date,
    end: Date,
    value: Double? = nil,
    unit: String? = nil,
    category: String? = nil,
    source: String? = nil,
    metadata: [String: String]? = nil
  ) {
    self.uuid = uuid
    self.type = type
    self.start = start
    self.end = end
    self.value = value
    self.unit = unit
    self.category = category
    self.source = source
    self.metadata = metadata
  }
}
