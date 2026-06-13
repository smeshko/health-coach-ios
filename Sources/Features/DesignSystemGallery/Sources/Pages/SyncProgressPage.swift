import DesignSystem
import SwiftUI

/// Composite gallery page — the `SyncProgressView` full-screen loading composite for its two in-scope
/// states (`.syncing` and `.generating`), matching `2 ·`/`3 · Loading` mockups. Each state is a
/// full-screen section, so the page tabs between them and the snapshot tests render the sections
/// directly (each already fills — and fits — the device frame).
struct SyncProgressPage: View {
  @State private var state: SyncProgressSection.State = .syncing

  var body: some View {
    VStack(spacing: 0) {
      Picker("State", selection: $state) {
        Text("Syncing").tag(SyncProgressSection.State.syncing)
        Text("Generating").tag(SyncProgressSection.State.generating)
        Text("Determinate").tag(SyncProgressSection.State.determinate)
        Text("Cancel").tag(SyncProgressSection.State.cancellable)
      }
      .pickerStyle(.segmented)
      .padding(CoachSpacing.spaceMd)

      SyncProgressSection(state: state)
    }
    .background(.coachBackground)
    .navigationTitle("SyncProgress")
  }
}

/// One full-screen `SyncProgressView` state on the product background — snapshotted directly.
struct SyncProgressSection: View {
  let state: State

  enum State {
    case syncing
    case generating
    case determinate
    case cancellable
  }

  var body: some View {
    switch state {
    case .syncing:
      // Indeterminate (Phase 12.1, D5): no `progress` → the ring spins an honest fixed arc.
      SyncProgressView(
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
        title: "Building today's brief…",
        subtitle: "Weighing your recovery, sleep and yesterday's load. This takes a few seconds.",
        steps: [
          .init(id: 0, label: "Health data synced", state: .done),
          .init(id: 1, label: "Building today's brief", state: .active),
        ]
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.coachBackground)
    case .determinate:
      // The determinate trim — kept for a future real-progress source; `progress` drives the arc.
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
    case .cancellable:
      // The blocking-sync screen with the quiet Cancel affordance (Phase 12.1, D4).
      SyncProgressView(
        title: "Syncing health data…",
        subtitle: "Pulling sleep, HRV and resting heart rate from Apple Health.",
        steps: [
          .init(id: 0, label: "Syncing health data", state: .active),
          .init(id: 1, label: "Building today's brief", state: .pending),
        ],
        cancelAction: {}
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.coachBackground)
    }
  }
}
