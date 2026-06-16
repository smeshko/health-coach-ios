// Reminders-section snapshots (Phase 10.3): the "Good morning check-in" toggle in its ON, OFF, and
// DENIED (toggle off + "allow notifications" hint) states, light + dark on the single reference device.
// `#if canImport(UIKit)`-guarded (empty module on the macOS host). Runs on the iOS 26 simulator.

#if canImport(UIKit)
  import CoachTestSupport
  import ComposableArchitecture
  import Foundation
  import NotificationClient
  import Sharing
  import SnapshotTesting
  import SwiftUI
  import Testing

  @testable import SettingsFeature

  @Suite(.serialized)
  @MainActor
  struct SettingsRemindersSnapshotTests {
    private static func suite(remindersEnabled: Bool, named: String) -> UserDefaults {
      // Unique per test so swift-sharing's global @Shared(.appStorage) cache never reuses a stale
      // reference across the (serialized) snapshot cases.
      let name = "settings-reminders-snap-\(named)"
      let defaults = UserDefaults(suiteName: name)!
      defaults.removePersistentDomain(forName: name)
      defaults.set(remindersEnabled, forKey: "settingsRemindersEnabled")
      return defaults
    }

    // `testName` is forwarded so each case writes its own snapshot file (the shared helper's `#function`
    // would otherwise collide all three onto one name).
    private func snapshot(
      remindersEnabled: Bool,
      auth: NotificationAuthorizationStatus,
      testName: String
    ) {
      withDependencies {
        // `remindersEnabled` is seeded via the appStorage suite (the @Shared toggle reads it).
        $0.defaultAppStorage = Self.suite(remindersEnabled: remindersEnabled, named: testName)
      } operation: {
        var state = SettingsFeature.State()
        state.load = .loaded
        state.notificationAuthorization = auth
        // Render the REMINDERS section in isolation (the full settings list is tall and clips this
        // section below the reference-device fold). The section reads only effective-state derivations,
        // so no live effects run.
        assertCoachSnapshot(
          of: List {
            RemindersSection(store: Store(initialState: state) { SettingsFeature() })
          },
          testName: testName
        )
      }
    }

    @Test func test_remindersOn() {
      snapshot(remindersEnabled: true, auth: .authorized, testName: "test_remindersOn")
    }

    @Test func test_remindersOff() {
      snapshot(remindersEnabled: false, auth: .notDetermined, testName: "test_remindersOff")
    }

    @Test func test_remindersDenied() {
      snapshot(remindersEnabled: true, auth: .denied, testName: "test_remindersDenied")
    }
  }
#endif
