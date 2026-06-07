import CoachCore
import Dependencies
import DomainModels
import Foundation

/// The local-only strength-test repository (ARCHITECTURE §7, PRD §7.3). `save(_:)` upserts the two
/// weekly numbers by Europe/Sofia day (latest-wins); `current(date:)` returns the **latest strength
/// test at-or-before** the given Sofia day (not strictly that exact day) — so `SyncRepository` (4.3)
/// can find a test logged earlier in the same week. The app is week-agnostic: it sends today's
/// numbers and the **server** keys by ISO week. `.live` (GRDB) lives in `StrengthTestRepositoryLive`.
public struct StrengthTestRepository: Sendable {
  public var save: @Sendable (_ test: DomainModels.StrengthTest) async throws -> Void
  public var current: @Sendable (_ date: Date) async throws -> DomainModels.StrengthTest?

  public init(
    save: @escaping @Sendable (_ test: DomainModels.StrengthTest) async throws -> Void,
    current: @escaping @Sendable (_ date: Date) async throws -> DomainModels.StrengthTest?
  ) {
    self.save = save
    self.current = current
  }
}

extension StrengthTestRepository: TestDependencyKey {
  /// Empty-state default: no-op `save`, `nil` `current`.
  public static var testValue: StrengthTestRepository {
    StrengthTestRepository(save: { _ in }, current: { _ in nil })
  }

  /// Previews show a logged strength test for the requested day.
  public static var previewValue: StrengthTestRepository {
    StrengthTestRepository(
      save: { _ in },
      current: { date in DomainModels.StrengthTest(date: date, maxPushups: 30, maxPullups: 8) }
    )
  }
}

public extension DependencyValues {
  var strengthTestRepository: StrengthTestRepository {
    get { self[StrengthTestRepository.self] }
    set { self[StrengthTestRepository.self] = newValue }
  }
}
