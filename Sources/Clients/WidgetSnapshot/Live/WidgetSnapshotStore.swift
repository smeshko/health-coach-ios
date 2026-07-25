import CoachCore
import DomainModels
import Foundation
import WidgetSnapshotClient

/// The snapshot file store: `widget-snapshot.json` in a directory (the App Group container in
/// production; a temp directory in host tests). Writes are atomic (`.atomic` = write-then-rename),
/// so the extension never observes a torn file — that is the whole cross-process story (the app
/// writes, the extension only reads; no `NSFileCoordinator`). WITHIN the app process, concurrent
/// read→merge→write cycles are serialized by the `liveValue`'s actor (see
/// `WidgetSnapshotClient+Live.swift`), so sibling section writers can never lose each other's
/// sections (PLAN Risks / validation round-1 #3).
public struct WidgetSnapshotStore: Sendable {
  /// The shared App Group both targets are entitled to (TASK-006 adds it to both entitlements).
  public static let appGroupID = "group.com.smeshko.CoachApp"

  public let fileURL: URL

  public init(directoryURL: URL) {
    fileURL = directoryURL.appendingPathComponent("widget-snapshot.json")
  }

  /// The store over the App Group container — `nil` when the container is unavailable (e.g. the
  /// macOS host or a missing entitlement); callers degrade silently, never crash.
  public static func appGroupStore() -> WidgetSnapshotStore? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
      .map(WidgetSnapshotStore.init(directoryURL:))
  }

  /// The current snapshot; `nil` on a missing file OR undecodable bytes — a corrupt mirror is "no
  /// snapshot" (the Phase 19.2 degrade-don't-fail convention), the next write repairs it.
  public func read() -> WidgetSnapshot? {
    guard let data = try? Data(contentsOf: fileURL) else { return nil }
    return try? WidgetSnapshotCoding.makeDecoder().decode(WidgetSnapshot.self, from: data)
  }

  /// Atomic replace via the shared coding factory. Creates the parent directory on first write.
  public func write(_ snapshot: WidgetSnapshot) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    let data = try WidgetSnapshotCoding.makeEncoder().encode(snapshot)
    try data.write(to: fileURL, options: .atomic)
  }

  /// Load-merge-write today's brief into the `daily` section (see `merge(dailyBrief:into:)`).
  public func mergeDailyBrief(_ brief: DomainModels.DailyBrief, generatedAt: Date = Date()) throws {
    try write(Self.merge(dailyBrief: brief, into: read(), generatedAt: generatedAt))
  }

  /// Load-merge-write the week's plan into the `weekly` section (see `merge(weeklyPlan:into:)`).
  public func mergeWeeklyPlan(_ plan: DomainModels.WeeklyPlan, generatedAt: Date = Date()) throws {
    try write(Self.merge(weeklyPlan: plan, into: read(), generatedAt: generatedAt))
  }

  /// Load-merge-write the athlete's selected block for `day` into `daily.selectedSession` (Phase
  /// 21.2). Returns `false` (no write) when the merge declines — see `merge(selectedSession:day:)`.
  @discardableResult
  public func mergeSelectedSession(
    _ block: SessionBlock, day: Date, generatedAt: Date = Date()
  ) throws -> Bool {
    guard let merged = Self.merge(
      selectedSession: block, day: day, into: read(), generatedAt: generatedAt
    ) else { return false }
    try write(merged)
    return true
  }

  /// The pure daily merge (host-testable without any file I/O): replace only the `daily` section +
  /// the root `generatedAt`/`schemaVersion`, preserve `weekly` and `checkIn` verbatim. The existing
  /// `selectedSession` survives ONLY when the existing daily is the SAME Sofia day as `brief.date`
  /// (a same-day refresh keeps the athlete's pick; a new-day brief drops the stale prior-day
  /// selection — validation round-1 #2; 21.2 owns *writing* the selection).
  public static func merge(
    dailyBrief brief: DomainModels.DailyBrief,
    into existing: WidgetSnapshot?,
    generatedAt: Date
  ) -> WidgetSnapshot {
    let sameDaySelection: SessionBlock? =
      if let existingDaily = existing?.daily, existingDaily.isCurrent(at: brief.date) {
        existingDaily.selectedSession
      } else {
        nil
      }
    return WidgetSnapshot(
      generatedAt: generatedAt,
      daily: WidgetDailySnapshot(
        date: brief.date,
        readiness: brief.readiness,
        safetyGate: brief.safetyGate,
        plannedSession: brief.session,
        selectedSession: sameDaySelection,
        macroFocus: brief.macroFocus,
        intakeYesterday: brief.intakeYesterday
      ),
      weekly: existing?.weekly,
      checkIn: existing?.checkIn
    )
  }

  /// The pure weekly merge (Phase 21.4): replace only the `weekly` section + the root
  /// `generatedAt`/`schemaVersion`, preserve `daily` and `checkIn` verbatim. Core sessions only —
  /// extras never reach the widget (the epic's weekly widget is core-only), and nothing
  /// progress-shaped is carried (plan-only, epic Out of scope).
  public static func merge(
    weeklyPlan plan: DomainModels.WeeklyPlan,
    into existing: WidgetSnapshot?,
    generatedAt: Date
  ) -> WidgetSnapshot {
    WidgetSnapshot(
      generatedAt: generatedAt,
      daily: existing?.daily,
      weekly: WidgetWeeklySnapshot(
        isoWeek: plan.isoWeek,
        budgets: plan.budgets,
        targets: plan.targets,
        coreSessions: plan.core
      ),
      checkIn: existing?.checkIn
    )
  }

  /// The pure selection merge (Phase 21.2): set `daily.selectedSession` + the root `generatedAt`,
  /// preserving every other field verbatim. `nil` (no write) when there is no existing `daily` or it
  /// is for a DIFFERENT Sofia day than `day` — a selection without today's brief has nothing to
  /// attach to, and grafting it onto another day's brief would show a wrong session; the next brief
  /// mirror rebuilds the section and its same-day merge keeps the pick.
  public static func merge(
    selectedSession block: SessionBlock,
    day: Date,
    into existing: WidgetSnapshot?,
    generatedAt: Date
  ) -> WidgetSnapshot? {
    guard var snapshot = existing, var daily = snapshot.daily, daily.isCurrent(at: day) else {
      return nil
    }
    daily.selectedSession = block
    snapshot.daily = daily
    snapshot.generatedAt = generatedAt
    snapshot.schemaVersion = WidgetSnapshot.currentSchemaVersion
    return snapshot
  }
}
