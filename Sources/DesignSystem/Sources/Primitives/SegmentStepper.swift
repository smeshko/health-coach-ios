import SwiftUI

/// A 0–10 segment stepper for the knee-pain input (`1 · Daily Check-in.png`): round `−`/`+` buttons
/// flank a row of short rounded dashes filled up to `value` in the warning accent. `−`/`+` clamp within
/// `range` — this clamp is UI convenience only; the authoritative 0–10 clamp lives in `CheckInComponent`
/// (DECISIONS #2), which remains the single writer of stored `kneePain`.
public struct SegmentStepper: View {
  @Binding var value: Int
  let range: ClosedRange<Int>

  public init(value: Binding<Int>, range: ClosedRange<Int> = 0 ... 10) {
    _value = value
    self.range = range
  }

  public var body: some View {
    let segments = Array(stride(from: range.lowerBound + 1, through: range.upperBound, by: 1))
    HStack(spacing: CoachSpacing.spaceSm) {
      StepButton(symbol: "minus", isEnabled: value > range.lowerBound) {
        value = max(range.lowerBound, value - 1)
      }
      HStack(spacing: CoachSpacing.space2xs) {
        ForEach(segments, id: \.self) { segment in
          Capsule()
            .fill(segment <= value ? Color.coachWarning : Color.coachBorder)
            .frame(height: Metrics.segmentHeight)
            .frame(maxWidth: .infinity)
        }
      }
      .frame(maxWidth: .infinity)
      StepButton(symbol: "plus", isEnabled: value < range.upperBound) {
        value = min(range.upperBound, value + 1)
      }
    }
  }

  /// A round `−`/`+` control — a sunken-surface circle; dims to a subtle glyph when at the bound.
  private struct StepButton: View {
    let symbol: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        Image(systemName: symbol)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(isEnabled ? .coachForeground : .coachForegroundSubtle)
          .frame(width: Metrics.buttonSize, height: Metrics.buttonSize)
          .background(Circle().fill(.coachBorder))
      }
      .buttonStyle(.coachPressable)
      .disabled(!isEnabled)
    }
  }
}

/// Segment/button sizing — named constants, not inline literals.
private enum Metrics {
  static let segmentHeight: CGFloat = 6
  static let buttonSize: CGFloat = 40
}
