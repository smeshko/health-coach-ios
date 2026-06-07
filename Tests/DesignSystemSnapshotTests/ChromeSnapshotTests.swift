// Chrome/nav + full-screen state composites snapshots (Phase 5.2 TASK-003) — light + dark.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import XCTest

  @testable import DesignSystem

  @MainActor
  final class ChromeSnapshotTests: XCTestCase {
    func test_chrome() {
      assertCoachSnapshot(of: ChromeCatalogView())
    }

    func test_restDay() {
      assertCoachSnapshot(of: RestDay())
    }

    func test_messageState() {
      assertCoachSnapshot(of: MessageState(
        icon: Icon.reconnect.systemName,
        tone: .negative,
        title: "Reconnect to continue",
        body: "Your session expired. Reconnect to sync today's plan.",
        primary: .init(title: "Reconnect", icon: Icon.retry.systemName, action: {}),
        secondaryTitle: "Not now"
      ))
    }
  }
#endif
