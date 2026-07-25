import AppIntents
import CoachCore
import Dependencies
import DomainModels
import Foundation
import WidgetSnapshotClient

/// The check-in widget's "All clear" button intent (Phase 21.5). Executes IN the widget extension
/// process — no app launch, and no DB there: the whole write goes through the
/// `WidgetSnapshotClient` INTERFACE (`logCheckInFromWidget` appends the pending all-clear to the
/// App Group inbox, flips the snapshot to logged, and reloads timelines — the extension links the
/// live store, so the dynamic `liveValue` lookup resolves it). The app drains the inbox into GRDB
/// via `CheckInRepository.drainWidgetInbox` on its next launch/foreground.
public struct CheckInAllClearIntent: AppIntent {
  public static let title: LocalizedStringResource = "Log all-clear check-in"

  // Module-qualified: `AppIntents` ships its OWN `@Dependency` wrapper, which shadows
  // swift-dependencies' in any file importing both.
  @Dependencies.Dependency(\.widgetSnapshot) var widgetSnapshot

  public init() {}

  public func perform() async throws -> some IntentResult {
    // Explicit Sofia frame + `Date()` — the extension process never runs `prepareDependencies`.
    let today = Calendar.europeSofia.startOfDay(for: Date())
    await widgetSnapshot.logCheckInFromWidget(
      DomainModels.CheckIn(date: today, giSymptoms: false, kneePain: 0, illness: false)
    )
    return .result()
  }
}

/// The package-side AppIntents registration hook: the extension target's `AppIntentsPackage` lists
/// this module so the metadata extractor finds (and the widget button can execute) intents defined
/// in this SPM module rather than in the extension target itself (DECISIONS D4 keeps the extension
/// to the one `@main` bundle file).
public struct WidgetsUIAppIntentsPackage: AppIntentsPackage {}
