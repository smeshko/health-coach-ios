import Foundation

/// The `/brief/daily` response (`openapi.yaml` `DailyBrief`) — a `data`/`narrative` split.
public struct DailyBrief: Codable, Sendable, Equatable {
  public var data: DailyBriefData
  public var narrative: [NarrativeSection]

  public init(data: DailyBriefData, narrative: [NarrativeSection]) {
    self.data = data
    self.narrative = narrative
  }
}

/// The structured payload of a daily brief (`openapi.yaml` `DailyBriefData`). `date` is a calendar
/// `date`; `generatedAt` is a plain `date-time` instant.
public struct DailyBriefData: Codable, Sendable, Equatable {
  public var date: WireCalendarDate
  public var readiness: Readiness
  public var safetyGate: SafetyGate
  public var session: SessionBlock
  public var alternatives: [SessionBlock]
  public var skipOk: Bool
  public var macroFocus: MacroFocus
  public var intakeYesterday: IntakeSummary?
  public var generatedAt: Date
  public var cached: Bool
  public var constitutionVersion: String?

  public init(
    date: WireCalendarDate,
    readiness: Readiness,
    safetyGate: SafetyGate,
    session: SessionBlock,
    alternatives: [SessionBlock],
    skipOk: Bool,
    macroFocus: MacroFocus,
    intakeYesterday: IntakeSummary? = nil,
    generatedAt: Date,
    cached: Bool,
    constitutionVersion: String? = nil
  ) {
    self.date = date
    self.readiness = readiness
    self.safetyGate = safetyGate
    self.session = session
    self.alternatives = alternatives
    self.skipOk = skipOk
    self.macroFocus = macroFocus
    self.intakeYesterday = intakeYesterday
    self.generatedAt = generatedAt
    self.cached = cached
    self.constitutionVersion = constitutionVersion
  }
}
