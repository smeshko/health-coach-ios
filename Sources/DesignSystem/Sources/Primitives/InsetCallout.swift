import SwiftUI

/// A contained icon-led callout — a leading **square** `IconBadge`, a muted headline line, and the
/// prominent content beneath it, on a soft surface. The shared shape behind the session-card prehab
/// add-on, the rest-day optional-activity suggestion, and the forced-rest check-in echo: an icon framing
/// a small muted label above the line that actually matters.
///
/// - `headline` is the muted kicker (omit it for a single prominent line, e.g. the prehab add-on).
/// - `content` is the prominent line — always shown.
/// - `surface` picks the container: `.sunken` (an inset tint inside a card) or `.raised` (an elevated
///   surface card, the forced-rest echo's treatment).
public struct InsetCallout: View {
  /// The container treatment — an inset tint within a card, or an elevated surface card.
  public enum Surface: Sendable {
    case sunken
    case raised
  }

  let icon: String
  let tone: Tone
  let headline: String?
  let content: String
  let surface: Surface

  public init(
    icon: String,
    tone: Tone = .accent,
    headline: String? = nil,
    content: String,
    surface: Surface = .sunken
  ) {
    self.icon = icon
    self.tone = tone
    self.headline = headline
    self.content = content
    self.surface = surface
  }

  public var body: some View {
    HStack(spacing: CoachSpacing.spaceSm) {
      IconBadge(icon, shape: .square, size: .md, tone: tone)
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        if let headline {
          Text(headline)
            .font(.coachTextXs)
            .foregroundStyle(.coachForegroundMuted)
        }
        Text(content)
          .font(.coachTextSm)
          .foregroundStyle(.coachForeground)
      }
      Spacer(minLength: 0)
    }
    .padding(CoachSpacing.spaceMd)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(background)
  }

  @ViewBuilder private var background: some View {
    switch surface {
    case .sunken:
      RoundedRectangle(cornerRadius: CoachRadius.md, style: .continuous).fill(.coachSurfaceSunken)
    case .raised:
      RoundedRectangle(cornerRadius: CoachRadius.md, style: .continuous)
        .fill(.coachSurface)
        .overlay(
          RoundedRectangle(cornerRadius: CoachRadius.md, style: .continuous)
            .stroke(.coachBorder, lineWidth: 1)
        )
    }
  }
}
