import DomainModels
import Foundation

/// The App-Group JSON mirror the widgets render from (Phase 21.1, DECISIONS D2). The FULL schema
/// lands now — daily core + optional weekly + optional check-in sections — so 21.2–21.5 add writers
/// and UI, never schema surgery. Sections embed `DomainModels` types directly (all already
/// `Codable + Equatable + Sendable`); a decode of an older file simply yields `nil` sections.
public struct WidgetSnapshot: Equatable, Codable, Sendable {
  /// The frozen wire-shape version (see the pinned-JSON test). Bump only on a breaking change.
  public static let currentSchemaVersion = 1

  public var schemaVersion: Int
  /// When the app last wrote any section of this snapshot.
  public var generatedAt: Date
  public var daily: WidgetDailySnapshot?
  public var weekly: WidgetWeeklySnapshot?
  public var checkIn: WidgetCheckInState?

  public init(
    schemaVersion: Int = WidgetSnapshot.currentSchemaVersion,
    generatedAt: Date,
    daily: WidgetDailySnapshot? = nil,
    weekly: WidgetWeeklySnapshot? = nil,
    checkIn: WidgetCheckInState? = nil
  ) {
    self.schemaVersion = schemaVersion
    self.generatedAt = generatedAt
    self.daily = daily
    self.weekly = weekly
    self.checkIn = checkIn
  }
}

/// The daily-brief section: today's readiness/gate/session/macros, mirrored on every daily cache
/// write. `selectedSession` stays `nil` until 21.2's selection writer fills it — "selected vs
/// planned" is `selectedSession ?? plannedSession` at render.
public struct WidgetDailySnapshot: Equatable, Codable, Sendable {
  /// The brief's Sofia day (server-stamped Sofia midnight, same as `DailyBrief.date`).
  public var date: Date
  public var readiness: Readiness
  public var safetyGate: SafetyGate
  public var plannedSession: SessionBlock
  public var selectedSession: SessionBlock?
  public var macroFocus: MacroFocus
  public var intakeYesterday: IntakeSummary?

  public init(
    date: Date,
    readiness: Readiness,
    safetyGate: SafetyGate,
    plannedSession: SessionBlock,
    selectedSession: SessionBlock? = nil,
    macroFocus: MacroFocus,
    intakeYesterday: IntakeSummary? = nil
  ) {
    self.date = date
    self.readiness = readiness
    self.safetyGate = safetyGate
    self.plannedSession = plannedSession
    self.selectedSession = selectedSession
    self.macroFocus = macroFocus
    self.intakeYesterday = intakeYesterday
  }
}

/// The weekly-plan section (written by 21.4): plan-only budgets/targets/core sessions — never
/// used-vs-budget progress (epic Out of scope). Deload rides `budgets.deload`.
public struct WidgetWeeklySnapshot: Equatable, Codable, Sendable {
  /// The canonical `"%04d-W%02d"` week key (e.g. `2026-W07`) — `BriefRepositoryLive.isoWeekKey`'s
  /// format.
  public var isoWeek: String
  public var budgets: WeeklyBudgets
  public var targets: WeeklyTargets
  public var coreSessions: [PlannedSession]

  public init(
    isoWeek: String,
    budgets: WeeklyBudgets,
    targets: WeeklyTargets,
    coreSessions: [PlannedSession] = []
  ) {
    self.isoWeek = isoWeek
    self.budgets = budgets
    self.targets = targets
    self.coreSessions = coreSessions
  }
}

/// Today's check-in display state (written by 21.5). Display only — pending check-ins live in
/// 21.5's App-Group inbox file, never here.
public struct WidgetCheckInState: Equatable, Codable, Sendable {
  /// The Sofia day this state refers to.
  public var date: Date
  public var logged: Bool
  /// Where today's check-in came from; `nil` while unlogged.
  public var source: WidgetCheckInSource?

  public init(date: Date, logged: Bool, source: WidgetCheckInSource? = nil) {
    self.date = date
    self.logged = logged
    self.source = source
  }
}

/// The origin of a logged check-in shown on the widget.
public enum WidgetCheckInSource: String, Codable, Equatable, Sendable {
  case app, widget
}
