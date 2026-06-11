import DesignSystem
import SwiftUI

/// Snapshot fixture for the `SyncProgressView` composite — the two in-scope states (`.syncing` and
/// `.generating`) on the product background, matching `2 ·`/`3 · Loading` mockups.
struct SyncProgressCatalogView: View {
  let state: State

  enum State {
    case syncing
    case generating
  }

  var body: some View {
    switch state {
    case .syncing:
      SyncProgressView(
        progress: 0.3,
        title: "Syncing health data…",
        subtitle: "Pulling sleep, HRV and resting heart rate from Apple Health.",
        steps: [
          .init(id: 0, label: "Syncing health data", state: .active),
          .init(id: 1, label: "Building today's brief", state: .pending),
        ]
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.coachBackground)
    case .generating:
      SyncProgressView(
        progress: 0.7,
        title: "Building today's brief…",
        subtitle: "Weighing your recovery, sleep and yesterday's load. This takes a few seconds.",
        steps: [
          .init(id: 0, label: "Health data synced", state: .done),
          .init(id: 1, label: "Building today's brief", state: .active),
        ]
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.coachBackground)
    }
  }
}
