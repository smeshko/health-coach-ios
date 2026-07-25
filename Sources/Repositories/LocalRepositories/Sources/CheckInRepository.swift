import CoachCore
import Dependencies
import DomainModels
import Foundation

/// The local-only daily check-in repository (ARCHITECTURE §7, PRD §7.2). A `Sendable` struct of
/// `@Sendable` closures: `save(_:)` upserts today's check-in by Europe/Sofia day (latest-wins) and
/// `current(date:)` reads the check-in for a given Sofia day (`nil` if none). `.live` (GRDB) lives
/// alongside this in the `LocalRepositories` module (the two local repos were merged here in Phase
/// 11.7); `SyncRepository` (4.3) reads `current(date:)` to attach today's check-in to the `/sync`
/// payload. No network — these inputs are local until a sync sends them.
public struct CheckInRepository: Sendable {
  public var save: @Sendable (_ checkIn: DomainModels.CheckIn) async throws -> Void
  public var current: @Sendable (_ date: Date) async throws -> DomainModels.CheckIn?
  /// Drain the widget's App Group check-in inbox into the DB (Phase 21.5), called on launch/
  /// foreground. Idempotent: a pending entry persists ONLY when no record exists for its Sofia day —
  /// an in-app check-in (or an already-drained entry) always wins over a pending widget all-clear.
  public var drainWidgetInbox: @Sendable () async throws -> Void

  /// `drainWidgetInbox` defaults to a no-op so pre-21.5 construction sites keep compiling.
  public init(
    save: @escaping @Sendable (_ checkIn: DomainModels.CheckIn) async throws -> Void,
    current: @escaping @Sendable (_ date: Date) async throws -> DomainModels.CheckIn?,
    drainWidgetInbox: @escaping @Sendable () async throws -> Void = {}
  ) {
    self.save = save
    self.current = current
    self.drainWidgetInbox = drainWidgetInbox
  }
}

extension CheckInRepository: TestDependencyKey {
  /// Empty-state default: `save` is a no-op, `current` returns `nil` (no check-in logged). Tests that
  /// need a stored value inject `.live` over an in-memory `Database`.
  public static var testValue: CheckInRepository {
    CheckInRepository(save: { _ in }, current: { _ in nil })
  }

  /// Previews show a logged check-in for the requested day.
  public static var previewValue: CheckInRepository {
    CheckInRepository(
      save: { _ in },
      current: { date in DomainModels.CheckIn(date: date, giSymptoms: false, kneePain: 0, illness: false) }
    )
  }
}

public extension DependencyValues {
  var checkInRepository: CheckInRepository {
    get { self[CheckInRepository.self] }
    set { self[CheckInRepository.self] = newValue }
  }
}
