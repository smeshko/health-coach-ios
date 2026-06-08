import Foundation

/// JSON codec for the serialized domain body stored in the composite cache records
/// (daily brief / weekly plan / profile). Single encode/decode path so all three stay lossless
/// (TASK-004 REFACTOR). This is an internal storage format, not the wire contract — the default
/// `Date` strategy round-trips exactly, so no custom date handling is needed here.
enum DomainBodyCoder {
  static func encode(_ value: some Encodable) throws -> Data {
    try JSONEncoder().encode(value)
  }

  static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    try JSONDecoder().decode(type, from: data)
  }
}
