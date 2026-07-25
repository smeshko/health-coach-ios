import Foundation

/// The ONE wire format for the snapshot file: ISO-8601 dates, shared by the live store, the tests,
/// and the extension's reader — so both processes always agree on the encoded shape (DECISIONS D2).
public enum WidgetSnapshotCoding {
  public static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  public static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
