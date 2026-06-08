import Dependencies
import Foundation

public extension DependencyValues {
  /// Pin `\.calendar` and `\.timeZone` to Europe/Sofia — the coaching server's frame.
  ///
  /// Call from the app's composition root so every `ISOWeek` / date computation resolves in
  /// Europe/Sofia regardless of the device locale:
  ///
  /// ```swift
  /// prepareDependencies { $0.useEuropeSofia() }
  /// ```
  ///
  /// Tests pin the same keys via `withDependencies { $0.useEuropeSofia() }` (and override `\.date`
  /// to a fixed instant) for deterministic ISO-week assertions.
  mutating func useEuropeSofia() {
    calendar = .europeSofia
    timeZone = .europeSofia
  }
}
