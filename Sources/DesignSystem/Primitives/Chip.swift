import SwiftUI

/// An outlined neutral chip for metadata ("5 km", "RPE 6") and flag badges. Neutral shell
/// (`$bg` fill, `$border` stroke); the flag variant recolors the leading + label to a status color
/// while keeping the neutral shell.
public struct Chip: View {
  /// The leading slot.
  public enum Leading: Sendable {
    case none
    case dot(Color)
    case icon(String)
  }

  let text: String
  let leading: Leading
  let textColor: Color
  let font: Font

  public init(
    _ text: String,
    leading: Leading = .none,
    textColor: Color = .coachForegroundMuted,
    font: Font = .coachTextXs
  ) {
    self.text = text
    self.leading = leading
    self.textColor = textColor
    self.font = font
  }

  public var body: some View {
    HStack(spacing: CoachSpacing.spaceXs) {
      switch leading {
      case .none:
        EmptyView()
      case let .dot(color):
        Circle().fill(color).frame(width: 8, height: 8)
      case let .icon(name):
        Image(systemName: name).font(.system(size: 12, weight: .semibold))
      }
      Text(text).font(font)
    }
    .foregroundStyle(textColor)
    .padding(.vertical, CoachSpacing.spaceXs)
    .padding(.horizontal, CoachSpacing.spaceSm)
    .background(Capsule().fill(.coachBackground))
    .overlay(Capsule().stroke(.coachBorder, lineWidth: 1))
  }
}
