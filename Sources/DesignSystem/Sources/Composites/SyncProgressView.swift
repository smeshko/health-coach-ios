import SwiftUI

/// A full-screen loading state: a circular progress ring with a centered health icon, a title +
/// subtitle, and an ordered stepped checklist (`2 · Loading — Syncing.png` / `3 · Loading — Building
/// brief.png`). Each step is `.done` (teal checkmark), `.active` (open accent arc, bold label), or
/// `.pending` (hollow circle, muted label). Parameterized by a `[Step]` list, so the deferred first-run
/// 3-step state is a data change, not a new component (DECISIONS #3). Purely presentational — the
/// feature supplies `progress`, copy, and the step states.
/// One row in a `SyncProgressView` checklist. `state` drives the leading indicator + label emphasis.
public struct SyncStep: Identifiable, Sendable {
  public enum State: Sendable {
    case done
    case active
    case pending
  }

  public let id: Int
  public let label: String
  public let state: State

  public init(id: Int, label: String, state: State) {
    self.id = id
    self.label = label
    self.state = state
  }
}

public struct SyncProgressView: View {
  /// The ring trim. `nil` (the default) is an **honest indeterminate** spinner — `sync()` exposes no
  /// granular progress, so the ring shows a fixed partial arc that just spins, and the step checklist
  /// below is the real progress UI (Phase 12.1, DECISIONS D5). A non-nil value renders a determinate trim
  /// (kept for the gallery demo / future real progress).
  let progress: Double?
  let title: String
  let subtitle: String
  let steps: [SyncStep]
  /// An optional quiet "Cancel" affordance below the step list (Phase 12.1, DECISIONS D4). `nil` ⇒ no
  /// button — the cache-first open made the blocking sync rare, so cancel is opt-in per caller.
  let cancelAction: (() -> Void)?

  /// Drives the continuous spinner rotations (the ring + the active step arc). Flipped once in
  /// `onAppear`; the `repeatForever` animations key off it. Snapshot-safe: the resting end state is a
  /// full turn, which renders identically to the start frame.
  @State private var isSpinning = false

  public init(
    progress: Double? = nil,
    title: String,
    subtitle: String,
    steps: [SyncStep],
    cancelAction: (() -> Void)? = nil
  ) {
    self.progress = progress
    self.title = title
    self.subtitle = subtitle
    self.steps = steps
    self.cancelAction = cancelAction
  }

  public var body: some View {
    VStack(spacing: CoachSpacing.spaceLg) {
      ZStack {
        Circle()
          .stroke(.coachBorder, lineWidth: Metrics.ringWidth)
        Circle()
          // Indeterminate (`nil`) → a fixed partial arc that reads as a spinner; determinate → the trim.
          .trim(from: 0, to: progress.map { max(0, min(1, $0)) } ?? Metrics.indeterminateTrim)
          .stroke(.coachAccent, style: StrokeStyle(lineWidth: Metrics.ringWidth, lineCap: .round))
          .rotationEffect(.degrees(isSpinning ? 270 : -90))
          .animation(
            .linear(duration: Metrics.ringSpinDuration).repeatForever(autoreverses: false),
            value: isSpinning
          )
          .animation(.easeInOut(duration: Metrics.progressTweenDuration), value: progress)
        Image(systemName: Icon.heartPulse.systemName)
          .font(.system(size: Metrics.iconSize, weight: .regular))
          .foregroundStyle(.coachAccent)
      }
      .frame(width: Metrics.ringSize, height: Metrics.ringSize)
      .onAppear { isSpinning = true }

      VStack(spacing: CoachSpacing.spaceSm) {
        Text(title)
          .font(.coachText2xl)
          .foregroundStyle(.coachForeground)
          .multilineTextAlignment(.center)
        Text(subtitle)
          .font(.coachTextMd)
          .foregroundStyle(.coachForegroundMuted)
          .multilineTextAlignment(.center)
      }

      VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
        ForEach(steps) { step in
          StepRow(step: step)
        }
      }

      // A quiet, secondary Cancel below the progress content (Phase 12.1) — muted so it never competes
      // with the active loading state. Only rendered when a caller wires it.
      if let cancelAction {
        Button("Cancel", action: cancelAction)
          .font(.coachTextMd)
          .foregroundStyle(.coachForegroundMuted)
      }
    }
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity)
  }

  /// One checklist row — a leading state indicator + the label, emphasis driven by `state`. The
  /// `.active` arc spins continuously (same `onAppear` + `repeatForever` pattern as the ring).
  private struct StepRow: View {
    let step: SyncStep
    @State private var isSpinning = false

    var body: some View {
      HStack(spacing: CoachSpacing.spaceSm) {
        Group {
          switch step.state {
          case .done:
            ZStack {
              Circle().fill(.coachAccent)
              Image(systemName: Icon.checkmark.systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.coachOnAccent)
            }
          case .active:
            Circle()
              .trim(from: 0, to: 0.75)
              .stroke(.coachAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
              .rotationEffect(.degrees(isSpinning ? 270 : -90))
              .animation(
                .linear(duration: Metrics.stepSpinDuration).repeatForever(autoreverses: false),
                value: isSpinning
              )
              .onAppear { isSpinning = true }
          case .pending:
            Circle().stroke(.coachBorder, lineWidth: 2)
          }
        }
        .frame(width: Metrics.stepIndicator, height: Metrics.stepIndicator)
        Text(step.label)
          .font(.coachTextLg)
          .foregroundStyle(step.state == .pending ? .coachForegroundMuted : .coachForeground)
      }
    }
  }
}

/// Ring / icon / indicator sizing — named constants, not inline literals.
private enum Metrics {
  static let ringSize: CGFloat = 104
  static let ringWidth: CGFloat = 5
  static let iconSize: CGFloat = 30
  static let stepIndicator: CGFloat = 24
  /// One full turn of the big ring / the active step arc — slow enough to read as "working".
  static let ringSpinDuration: TimeInterval = 1.8
  static let stepSpinDuration: TimeInterval = 1.2
  /// The ring's trim tween when `progress` moves (e.g. a determinate gallery demo).
  static let progressTweenDuration: TimeInterval = 0.45
  /// The fixed partial arc of the **indeterminate** ring (`progress == nil`) — long enough to read as a
  /// working spinner, short enough not to look like a determinate near-full ring (Phase 12.1, D5).
  static let indeterminateTrim: CGFloat = 0.25
}
