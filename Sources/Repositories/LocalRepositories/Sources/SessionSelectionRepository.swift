import CoachCore
import Dependencies
import DomainModels
import Foundation

/// The local-only selected-daily-workout repository (DECISIONS D4/D5/D6). A `Sendable` struct of
/// `@Sendable` closures: `save(_:for:)` upserts the chosen `SessionBlock` for a Europe/Sofia day
/// (latest-wins) and `current(_:)` reads the block for a given Sofia day (`nil` if none). `.live` (GRDB)
/// lives alongside this in `LocalRepositories`; the parent `TodayFeature` (not the pure `SessionFeature`)
/// writes through on the selection delegate and seeds the carousel from `current(today)` on hydrate. No
/// network — the pick is local/display-only, like the brief cache it reconciles with.
public struct SessionSelectionRepository: Sendable {
  public var save: @Sendable (_ block: DomainModels.SessionBlock, _ date: Date) async throws -> Void
  public var current: @Sendable (_ date: Date) async throws -> DomainModels.SessionBlock?

  public init(
    save: @escaping @Sendable (_ block: DomainModels.SessionBlock, _ date: Date) async throws -> Void,
    current: @escaping @Sendable (_ date: Date) async throws -> DomainModels.SessionBlock?
  ) {
    self.save = save
    self.current = current
  }
}

extension SessionSelectionRepository: TestDependencyKey {
  /// Empty-state default: `save` is a no-op, `current` returns `nil` (no pick stored). Tests that need a
  /// stored value inject `.live` over an in-memory `Database`.
  public static var testValue: SessionSelectionRepository {
    SessionSelectionRepository(save: { _, _ in }, current: { _ in nil })
  }

  /// Previews carry no stored pick (the primary stays selected).
  public static var previewValue: SessionSelectionRepository {
    SessionSelectionRepository(save: { _, _ in }, current: { _ in nil })
  }
}

public extension DependencyValues {
  var sessionSelectionRepository: SessionSelectionRepository {
    get { self[SessionSelectionRepository.self] }
    set { self[SessionSelectionRepository.self] = newValue }
  }
}
