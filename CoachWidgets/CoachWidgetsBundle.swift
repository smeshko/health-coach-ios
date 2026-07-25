import AppIntents
import SwiftUI
import WidgetKit
import WidgetsUI
// The extension's composition root: linking (and importing) the live store here is what lets the
// WidgetsUI providers' `@Dependency(\.widgetSnapshot)` resolve the real App-Group-backed `liveValue`
// via swift-dependencies' dynamic conformance lookup — the extension process never runs
// `prepareDependencies`. Never import Database/GRDB/APIClient here (epic dependency criterion).
import WidgetSnapshotClientLive

/// The ONLY source in the extension target (DECISIONS D4): later phases append one widget line each;
/// all widget implementation lives in the WidgetsUI package module.
@main
struct CoachWidgetsBundle: WidgetBundle {
  var body: some Widget {
    SessionWidget()
    MacrosWidget()
    SkeletonWidget()
    WeeklyWidget()
    CheckInWidget()
  }
}

/// Registers the WidgetsUI package module with the AppIntents metadata extractor, so intents defined
/// there (Phase 21.5's "All clear" check-in button) are discoverable and executable in this
/// extension process.
struct CoachWidgetsAppIntentsPackage: AppIntentsPackage {
  static var includedPackages: [any AppIntentsPackage.Type] {
    [WidgetsUIAppIntentsPackage.self]
  }
}
