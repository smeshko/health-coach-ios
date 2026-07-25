import Dependencies
import DomainModels
import Foundation

/// The widget-snapshot mirror dependency (`@Dependency(\.widgetSnapshot)`): repositories fire
/// `updateDailyBrief`/`updateWeeklyPlan`/`updateSelectedSession` after each cache write; widget
/// providers `read` the mirrored file. The live side (`WidgetSnapshotClientLive`) owns the
/// App-Group JSON store + the WidgetKit timeline reload. Later phases ADD defaulted closure
/// params (`updateCheckIn`) — additive, never breaking (DECISIONS D6).
///
/// The `update*` closures are **non-throwing by contract**: the mirror is fire-and-forget — the
/// brief/plan/selection paths must never fail or slow down because a widget file couldn't be
/// written.
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

  public init(
    updateDailyBrief: @escaping @Sendable (DomainModels.DailyBrief) async -> Void,
    updateWeeklyPlan: @escaping @Sendable (DomainModels.WeeklyPlan) async -> Void = { _ in },
    updateSelectedSession: @escaping @Sendable (DomainModels.SessionBlock, Date) async -> Void = { _, _ in },
    read: @escaping @Sendable () async -> WidgetSnapshot?
  ) {
    self.updateDailyBrief = updateDailyBrief
    self.updateWeeklyPlan = updateWeeklyPlan
    self.updateSelectedSession = updateSelectedSession
    self.read = read
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
