import SwiftUI

/// A small square badge for a weekday in the weekly plan — a `core` day is filled with the tone's soft
/// tint + strong label; an `extra`/optional day is a neutral outlined shell.
public struct DayBadge: View {
  public let text: String
  public let tone: Tone
  public let isCore: Bool

  public init(_ text: String, tone: Tone = .accent, isCore: Bool = true) {
    self.text = text
    self.tone = tone
    self.isCore = isCore
  }

  public var body: some View {
    Text(text)
      .font(CoachFont.eyebrow)
      .foregroundStyle(isCore ? tone.foreground : CoachColor.foregroundMuted)
      .frame(width: ComponentMetrics.dayBadgeSize, height: ComponentMetrics.dayBadgeSize)
      .background(
        RoundedRectangle(cornerRadius: CoachRadius.sm)
          .fill(isCore ? tone.fill : CoachColor.background)
      )
      .overlay(
        RoundedRectangle(cornerRadius: CoachRadius.sm)
          .stroke(isCore ? Color.clear : CoachColor.border, lineWidth: 1)
      )
  }
}
