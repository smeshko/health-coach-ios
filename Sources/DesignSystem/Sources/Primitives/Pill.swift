import SwiftUI

/// A filled soft-tint tag — intensity labels ("Easy", "Threshold") and readiness bands. The frame is
/// the tone's soft fill, the leading + label its strong foreground (never a soft-on-soft pair).
public struct Pill: View {
  /// The leading slot.
  public enum Leading: Sendable {
    case none
    case dot
    case icon(String)
  }

  let text: String
  let tone: Tone
  let leading: Leading
  let uppercase: Bool

  public init(_ text: String, tone: Tone = .accent, leading: Leading = .none, uppercase: Bool = false) {
    self.text = text
    self.tone = tone
    self.leading = leading
    self.uppercase = uppercase
  }

  public var body: some View {
    HStack(spacing: CoachSpacing.spaceXs) {
      switch leading {
      case .none:
        EmptyView()
      case .dot:
        Circle().fill(tone.foreground).frame(width: 8, height: 8)
      case let .icon(name):
        Image(systemName: name).font(.system(size: 11, weight: .semibold))
      }
      Text(uppercase ? text.uppercased() : text)
        .font(uppercase ? .coachText2xs : .coachTextSm)
        .tracking(uppercase ? 0.4 : 0)
    }
    .foregroundStyle(tone.foreground)
    .padding(.vertical, CoachSpacing.space2xs)
    .padding(.horizontal, CoachSpacing.spaceSm)
    .background(Capsule().fill(tone.fill))
  }
}
