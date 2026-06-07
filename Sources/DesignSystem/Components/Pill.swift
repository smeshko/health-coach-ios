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

  public let text: String
  public let tone: Tone
  public let leading: Leading
  public let uppercase: Bool

  public init(_ text: String, tone: Tone = .accent, leading: Leading = .none, uppercase: Bool = false) {
    self.text = text
    self.tone = tone
    self.leading = leading
    self.uppercase = uppercase
  }

  public var body: some View {
    HStack(spacing: CoachSpacing.space6) {
      switch leading {
      case .none:
        EmptyView()
      case .dot:
        Circle().fill(tone.foreground).frame(width: 8, height: 8)
      case let .icon(name):
        Image(systemName: name).font(.system(size: 11, weight: .semibold))
      }
      Text(uppercase ? text.uppercased() : text)
        .font(uppercase ? CoachFont.eyebrow : CoachFont.dataEmphasis)
        .tracking(uppercase ? 0.4 : 0)
    }
    .foregroundStyle(tone.foreground)
    .padding(.vertical, CoachSpacing.space6)
    .padding(.horizontal, CoachSpacing.space12)
    .background(Capsule().fill(tone.fill))
  }
}
