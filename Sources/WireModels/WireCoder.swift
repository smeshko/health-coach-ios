import Foundation

/// The shared JSON coder configuration for the wire contract.
///
/// Every consumer (the `APIClient` in Epic 03, the decode tests here) uses these so the contract
/// is decoded/encoded one way:
/// - **Default keys** — the wire is already camelCase (`openapi.yaml` §Conventions), so there is
///   **no** `.convertFromSnakeCase` strategy; Swift property names match the wire keys 1:1.
/// - **Dual date strategy** — a single decoder-wide `.custom` strategy decodes **both**
///   `format: date` (`yyyy-MM-dd`) and Europe/Sofia `format: date-time` strings. On encode, the
///   `.custom` closure receives a bare `Date` with no field context, so it emits the `date-time`
///   (ISO-8601 instant) form; the seven `format: date` fields carry their own ``WireCalendarDate``
///   type that owns its `yyyy-MM-dd` encode (DECISIONS.md Decision 2).
///
/// Fresh instances are returned each call — `JSONDecoder`/`JSONEncoder` are reference types and
/// are not safely shared mutably across isolation domains (D2 strict concurrency).
public enum WireCoder {
  /// A `JSONDecoder` configured for the wire contract.
  public static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let string = try container.decode(String.self)
      guard let date = WireDateFormatters.parse(string) else {
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "Expected a `yyyy-MM-dd` date or an ISO-8601 date-time, got '\(string)'"
        )
      }
      return date
    }
    return decoder
  }

  /// A `JSONEncoder` configured for the wire contract.
  public static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .custom { date, encoder in
      var container = encoder.singleValueContainer()
      try container.encode(WireDateFormatters.isoString(from: date))
    }
    return encoder
  }
}
