import SwiftUI

/// A fixed-size rounded-square badge for a weekday in the weekly plan. A `core` day is a solid fill in
/// the tone's strong color with a white label; an optional day is a `surface` shell outlined in the
/// tone's strong color with a matching label. The canonical pair is a terracotta core (`.negative`) and
/// a gold optional (`.warning`), per the design system's "Day Badges" reference.
public struct DayBadge: View {
  let text: String
  let tone: Tone
  let isCore: Bool

  /// 44×44 — matches the design spec (and the iOS minimum tap target).
  private let side: CGFloat = 44

  public init(_ text: String, tone: Tone = .accent, isCore: Bool = true) {
    self.text = text
    self.tone = tone
    self.isCore = isCore
  }

  public var body: some View {
    Text(text)
      .font(.coachTextSm)
      .textCase(.uppercase)
      .foregroundStyle(isCore ? .coachOnAccent : tone.foreground)
      .frame(width: side, height: side)
      .background(
        RoundedRectangle(cornerRadius: CoachRadius.sm)
          .fill(isCore ? tone.foreground : .coachSurface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: CoachRadius.sm)
          .strokeBorder(isCore ? Color.clear : tone.foreground, lineWidth: 1.5)
      )
  }
}
