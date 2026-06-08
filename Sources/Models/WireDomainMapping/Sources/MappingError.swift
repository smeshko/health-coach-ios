/// An error raised when a DTO cannot be mapped to a total domain value.
///
/// Pure value type, no I/O. The only failure the mapping can produce is an out-of-set **required
/// singular** closed enum (a value structurally impossible to drop or null) — the repository
/// surfaces it as a domain error, never a crash (ARCHITECTURE §5, DECISIONS Decision 2).
public enum MappingError: Error, Equatable {
  /// A required singular closed-enum field carried a value outside the domain's closed set.
  case unmappableRequiredEnum(field: String, rawValue: String)
}
