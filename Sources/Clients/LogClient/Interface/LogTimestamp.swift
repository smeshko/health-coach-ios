import CoachCore
import Foundation

/// The single owner of the log-line timestamp contract — `yyyy-MM-dd HH:mm:ss.SSS` rendered/parsed in
/// the app's canonical Europe/Sofia frame (`Calendar.europeSofia`, the value `useEuropeSofia()` pins
/// `\.calendar` to). The writer-side renderer (`LogClient.live`) and the DEBUG log viewer's parser both
/// route through here, so the format has one home.
///
/// Deliberately **not** a shared `DateFormatter`: the live `log` closure is `@Sendable` and a static
/// `DateFormatter` is non-Sendable under Swift 6, so `format` uses the `Sendable` value-type
/// `Calendar.europeSofia` + `String(format:)` and `parse` reconstructs the instant from pure
/// `DateComponents`. A `Calendar` knows the zone's DST rules, so wall-clock rendering stays correct
/// across transitions (unlike a fixed UTC offset). A wall-clock string carries no UTC offset, so it
/// cannot uniquely round-trip instants inside Sofia's fall-back repeated hour; spring-forward boundaries
/// are unambiguous.
public enum LogTimestamp {
  /// Render `date` as `yyyy-MM-dd HH:mm:ss.SSS` in the Europe/Sofia frame.
  public static func format(_ date: Date) -> String {
    let parts = Calendar.europeSofia.dateComponents(
      [.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date
    )
    let millis = (parts.nanosecond ?? 0) / 1_000_000
    return String(
      format: "%04d-%02d-%02d %02d:%02d:%02d.%03d",
      parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
      parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0, millis
    )
  }

  /// Parse a `yyyy-MM-dd HH:mm:ss.SSS` wall-clock string back into a `Date`, interpreting it in the
  /// Europe/Sofia frame. Returns `nil` for a string that doesn't fit the shape (so a stray line stays
  /// visible rather than being date-filtered out).
  public static func parse(_ string: String) -> Date? {
    let halves = string.split(separator: " ")
    guard halves.count == 2 else { return nil }
    let dateParts = halves[0].split(separator: "-")
    let timeParts = halves[1].split(separator: ":")
    guard dateParts.count == 3, timeParts.count == 3 else { return nil }
    let secondParts = timeParts[2].split(separator: ".")
    guard
      let year = Int(dateParts[0]), let month = Int(dateParts[1]), let day = Int(dateParts[2]),
      let hour = Int(timeParts[0]), let minute = Int(timeParts[1]), let second = Int(secondParts[0])
    else { return nil }
    var components = DateComponents()
    components.timeZone = .europeSofia
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    components.nanosecond = (secondParts.count > 1 ? Int(secondParts[1]) ?? 0 : 0) * 1_000_000
    return Calendar.europeSofia.date(from: components)
  }
}
