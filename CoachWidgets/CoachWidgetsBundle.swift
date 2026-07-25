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
  }
}
