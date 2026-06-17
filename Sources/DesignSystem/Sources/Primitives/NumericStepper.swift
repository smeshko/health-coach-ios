import SwiftUI

/// A large-numeral counter — circular `−` / big centered numeral / circular `+` — for whole-number
/// inputs like the strength-test max-reps counts (`Strength Input Screen.png`). `−`/`+` clamp within
/// `range`, but this clamp is **defensive UI convenience only**: the consuming reducer stays the
/// authoritative writer of the stored value (mirrors `SegmentStepper`).
///
/// The titled-card chrome ("Max push-ups", the "max in one set" pill) lives in the consuming feature,
/// not here — this primitive is just the counter.
///
/// **Haptic contract (Phase 12.3, DECISIONS D4):** fires `.selection` on every `−`/`+` tap that changes
/// the value (the at-bound button is `.disabled`, so an enabled tap always moves `value`); the tick keys
/// on a private tap counter, so **programmatic** binding writes stay silent. Consumers don't add their own.
public struct NumericStepper: View {
  @Binding var value: Int
  let range: ClosedRange<Int>
  /// Increments on each value-changing `−`/`+` tap — the `.selection` haptic trigger, so programmatic
  /// writes to `value` stay silent.
  @State private var tapCount = 0

  public init(value: Binding<Int>, range: ClosedRange<Int> = 0 ... 300) {
    _value = value
    self.range = range
  }

  public var body: some View {
    HStack(spacing: CoachSpacing.spaceMd) {
      StepButton(symbol: "minus", isEnabled: value > range.lowerBound) {
        value = max(range.lowerBound, value - 1)
        tapCount += 1
      }
      Text("\(value)")
        .font(.coachTextDisplay)
        .monospacedDigit()
        .foregroundStyle(.coachForeground)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity)
      StepButton(symbol: "plus", isEnabled: value < range.upperBound) {
        value = min(range.upperBound, value + 1)
        tapCount += 1
      }
    }
    .sensoryFeedback(.selection, trigger: tapCount)
  }

  /// A round `−`/`+` control — a sunken-surface circle; dims to a subtle glyph when at the bound.
  private struct StepButton: View {
    let symbol: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        Image(systemName: symbol)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isEnabled ? .coachForeground : .coachForegroundSubtle)
          .frame(width: Metrics.buttonSize, height: Metrics.buttonSize)
          .background(Circle().fill(.coachBorder))
      }
      .buttonStyle(.coachPressable)
      .disabled(!isEnabled)
    }
  }
}

/// Button sizing — named constants, not inline literals.
private enum Metrics {
  static let buttonSize: CGFloat = 52
}
