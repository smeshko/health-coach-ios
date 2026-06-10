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
  let progress: Double
  let title: String
  let subtitle: String
  let steps: [SyncStep]

  public init(progress: Double, title: String, subtitle: String, steps: [SyncStep]) {
    self.progress = progress
    self.title = title
    self.subtitle = subtitle
    self.steps = steps
  }

  public var body: some View {
    VStack(spacing: CoachSpacing.spaceLg) {
      ZStack {
        Circle()
          .stroke(.coachBorder, lineWidth: Metrics.ringWidth)
        Circle()
          .trim(from: 0, to: max(0, min(1, progress)))
          .stroke(.coachAccent, style: StrokeStyle(lineWidth: Metrics.ringWidth, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Image(systemName: Icon.heartPulse.systemName)
          .font(.system(size: Metrics.iconSize, weight: .regular))
          .foregroundStyle(.coachAccent)
      }
      .frame(width: Metrics.ringSize, height: Metrics.ringSize)

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
    }
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity)
  }

  /// One checklist row — a leading state indicator + the label, emphasis driven by `state`.
  private struct StepRow: View {
    let step: SyncStep

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
              .rotationEffect(.degrees(-90))
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
}
