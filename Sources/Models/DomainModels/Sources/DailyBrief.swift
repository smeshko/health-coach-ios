import Foundation

/// The daily brief, with the wire `{ data, narrative }` envelope flattened — reducers/views see the
/// data fields and `narrative` directly.
public struct DailyBrief: Equatable, Sendable {
  public var date: Date
  public var readiness: Readiness
  public var safetyGate: SafetyGate
  public var session: SessionBlock
  /// Alternatives — guaranteed non-optional, defaults to empty.
  public var alternatives: [SessionBlock]
  public var skipOk: Bool
  public var macroFocus: MacroFocus
  /// Yesterday's intake — optional (`nil` when nothing was logged).
  public var intakeYesterday: IntakeSummary?
  public var generatedAt: Date
  public var cached: Bool
  public var constitutionVersion: String?
  /// Narrative — guaranteed non-optional, defaults to empty.
  public var narrative: [NarrativeSection]

  public init(
    date: Date,
    readiness: Readiness,
    safetyGate: SafetyGate,
    session: SessionBlock,
    alternatives: [SessionBlock] = [],
    skipOk: Bool,
    macroFocus: MacroFocus,
    intakeYesterday: IntakeSummary? = nil,
    generatedAt: Date,
    cached: Bool,
    constitutionVersion: String? = nil,
    narrative: [NarrativeSection] = []
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
    self.narrative = narrative
  }
}
