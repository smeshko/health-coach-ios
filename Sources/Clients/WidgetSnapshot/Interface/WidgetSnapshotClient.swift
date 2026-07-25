import Dependencies
import DomainModels
import Foundation

/// The widget-snapshot mirror dependency (`@Dependency(\.widgetSnapshot)`): repositories fire
/// `updateDailyBrief`/`updateWeeklyPlan`/`updateSelectedSession`/`updateCheckIn` after each cache
/// write; widget providers `read` the mirrored file. The live side (`WidgetSnapshotClientLive`)
/// owns the App-Group JSON store + the WidgetKit timeline reload. Later phases ADD defaulted
/// closure params — additive, never breaking (DECISIONS D6).
///
/// The `update*` closures are **non-throwing by contract**: the mirror is fire-and-forget — the
/// brief/plan/selection/check-in paths must never fail or slow down because a widget file couldn't
/// be written.
public struct WidgetSnapshotClient: Sendable {
  /// Merge today's brief into the snapshot's `daily` section and reload widget timelines.
  public var updateDailyBrief: @Sendable (DomainModels.DailyBrief) async -> Void
  /// Merge the week's plan into the snapshot's `weekly` section and reload widget timelines.
  public var updateWeeklyPlan: @Sendable (DomainModels.WeeklyPlan) async -> Void
  /// Merge the athlete's selected block for a Sofia day (Phase 21.2 — the SessionSelectionRepository
  /// save hook) into `daily.selectedSession` and reload widget timelines.
  public var updateSelectedSession: @Sendable (DomainModels.SessionBlock, Date) async -> Void
  /// The current snapshot, `nil` when no file exists (or it can't be decoded).
  public var read: @Sendable () async -> WidgetSnapshot?
  /// Merge today's check-in display state into the snapshot's `checkIn` section and reload widget
  /// timelines (Phase 21.5). App-side writer, fired by `CheckInRepository.save` — same fire-and-forget
  /// contract as `updateDailyBrief`.
  public var updateCheckIn: @Sendable (WidgetCheckInState) async -> Void
  /// The widget "All clear" AppIntent's whole write (Phase 21.5), running in the EXTENSION process
  /// (no DB there): append the pending check-in to the App Group inbox file, flip the snapshot's
  /// `checkIn` section to logged (`source: .widget`), and reload timelines.
  public var logCheckInFromWidget: @Sendable (DomainModels.CheckIn) async -> Void
  /// The pending widget check-ins awaiting the app-side drain; `[]` when none (or unreadable).
  public var pendingCheckIns: @Sendable () async -> [DomainModels.CheckIn]
  /// Remove the inbox file after a completed drain.
  public var clearPendingCheckIns: @Sendable () async -> Void

  /// The later-phase closures default to no-ops so 21.1-era construction sites (tests overriding only
  /// the daily mirror) keep compiling — additive, never breaking (DECISIONS D6).
  public init(
    updateDailyBrief: @escaping @Sendable (DomainModels.DailyBrief) async -> Void,
    updateWeeklyPlan: @escaping @Sendable (DomainModels.WeeklyPlan) async -> Void = { _ in },
    updateSelectedSession: @escaping @Sendable (DomainModels.SessionBlock, Date) async -> Void = { _, _ in },
    read: @escaping @Sendable () async -> WidgetSnapshot?,
    updateCheckIn: @escaping @Sendable (WidgetCheckInState) async -> Void = { _ in },
    logCheckInFromWidget: @escaping @Sendable (DomainModels.CheckIn) async -> Void = { _ in },
    pendingCheckIns: @escaping @Sendable () async -> [DomainModels.CheckIn] = { [] },
    clearPendingCheckIns: @escaping @Sendable () async -> Void = {}
  ) {
    self.updateDailyBrief = updateDailyBrief
    self.updateWeeklyPlan = updateWeeklyPlan
    self.updateSelectedSession = updateSelectedSession
    self.read = read
    self.updateCheckIn = updateCheckIn
    self.logCheckInFromWidget = logCheckInFromWidget
    self.pendingCheckIns = pendingCheckIns
    self.clearPendingCheckIns = clearPendingCheckIns
  }
}

extension WidgetSnapshotClient: TestDependencyKey {
  /// No-op update + nil read — the safe default that keeps every un-overridden suite (e.g.
  /// BriefRepositoryLiveTests) green; tests asserting the mirror inject a recording override.
  public static var testValue: WidgetSnapshotClient {
    WidgetSnapshotClient(updateDailyBrief: { _ in }, read: { nil })
  }

  /// Previews never touch the App Group container.
  public static var previewValue: WidgetSnapshotClient {
    WidgetSnapshotClient(updateDailyBrief: { _ in }, read: { nil })
  }
}

public extension DependencyValues {
  var widgetSnapshot: WidgetSnapshotClient {
    get { self[WidgetSnapshotClient.self] }
    set { self[WidgetSnapshotClient.self] = newValue }
  }
}
