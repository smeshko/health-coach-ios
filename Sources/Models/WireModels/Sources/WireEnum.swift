import Foundation

/// A closed wire enum that ``WireEnum`` can wrap — any String-backed enum. (Marker protocol so the
/// `WireEnum` generic constraint fits on one line.)
public protocol WireEnumWrapped: RawRepresentable, Sendable, Hashable where RawValue == String {}

/// An unknown-tolerant wrapper around a closed wire enum.
///
/// A plain `enum: String, Codable` *throws* `DataCorrupted` on an unrecognised rawValue, which
/// would reject an entire otherwise-valid brief when the backend adds (say) a new `card`. The wire
/// contract's forward-compatibility rule (ARCHITECTURE §5 / principle #1: "a new backend flag never
/// fails a brief") requires the opposite: an unknown value must decode without throwing and
/// preserve its raw string (Phase 2.2 maps it to a semantic `.unknown(String)`).
///
/// `WireEnum` wraps any `RawRepresentable` String enum and decodes an unrecognised value into
/// `.unknown(raw)` rather than throwing; re-encoding emits the preserved raw string for a lossless
/// round-trip (DECISIONS.md Decision 1). One generic implementation gives all ten wire enums
/// identical behaviour.
public enum WireEnum<Wrapped: WireEnumWrapped>: Sendable, Equatable, Hashable {
  /// A recognised wire value.
  case known(Wrapped)
  /// An unrecognised raw value, preserved verbatim.
  case unknown(String)

  public init(_ wrapped: Wrapped) {
    self = .known(wrapped)
  }

  public init(rawValue: String) {
    if let known = Wrapped(rawValue: rawValue) {
      self = .known(known)
    } else {
      self = .unknown(rawValue)
    }
  }

  /// The raw wire string for either case.
  public var rawValue: String {
    switch self {
    case let .known(value):
      value.rawValue
    case let .unknown(raw):
      raw
    }
  }

  /// The wrapped value when recognised, else `nil`.
  public var known: Wrapped? {
    if case let .known(value) = self {
      return value
    }
    return nil
  }
}

extension WireEnum: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    try self.init(rawValue: container.decode(String.self))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
