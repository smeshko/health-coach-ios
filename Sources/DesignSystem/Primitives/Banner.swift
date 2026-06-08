import SwiftUI

/// A tonal banner — a soft-tinted rounded card with a leading status icon, a strong title, and a muted
/// subtitle. The fill is the tone's soft tint; the icon is its strong foreground (never a soft-on-soft
/// pair). Swap the `tone` per meaning (accent / warning / negative / positive).
public struct Banner: View {
  let icon: String
  let tone: Tone
  let title: String?
  let message: String

  public init(icon: String, tone: Tone = .accent, title: String?, message: String) {
    self.icon = icon
    self.tone = tone
    self.title = title
    self.message = message
  }

  public var body: some View {
    HStack(alignment: .top, spacing: CoachSpacing.spaceSm) {
      Image(systemName: icon)
        .font(.system(size: Metrics.bannerIcon))
        .foregroundStyle(tone.foreground)

      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        if let title {
          Text(title).font(.coachTextSm).foregroundStyle(tone.foreground)
        }
        Text(message).font(.coachTextXs).foregroundStyle(tone.foreground)
      }

      Spacer()
    }
    .padding(CoachSpacing.spaceMd)
    .background(RoundedRectangle(cornerRadius: CoachRadius.card).fill(tone.fill))
  }
}

/// Leading-icon point size — a named constant, not an inline literal.
private enum Metrics {
  static let bannerIcon: CGFloat = 18
}
