import Foundation

/// A morning self-report check-in (`openapi.yaml` `DailyCheckin`). `date` is a calendar `date`.
///
/// No body-weight field — weight arrives as a `body_mass` ``HealthRecord``.
public struct DailyCheckin: Codable, Sendable, Equatable {
  public var date: WireCalendarDate
  public var giSymptoms: Bool
  public var kneePain: Int
  public var illness: Bool

  public init(date: WireCalendarDate, giSymptoms: Bool, kneePain: Int, illness: Bool) {
    self.date = date
    self.giSymptoms = giSymptoms
    self.kneePain = kneePain
    self.illness = illness
  }
}
