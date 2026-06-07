import SwiftUI

/// A single macro cell — a label over its value. The emphasized variant (protein, the daily
/// non-negotiable, §7.4.4) renders with stronger weight + an accent treatment.
public struct MacroRow: View {
  public let label: String
  public let value: String
  public let emphasis: Bool

  public init(label: String, value: String, emphasis: Bool = false) {
    self.label = label
    self.value = value
    self.emphasis = emphasis
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space4) {
      Text(label).font(CoachFont.eyebrow).foregroundStyle(CoachColor.foregroundSubtle)
      Text(value)
        .font(emphasis ? CoachFont.cardHeadline : CoachFont.secondaryMeta)
        .foregroundStyle(emphasis ? CoachColor.accent : CoachColor.foreground)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(CoachSpacing.space12)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.sm)
        .fill(emphasis ? CoachColor.accentSoft : CoachColor.background)
    )
  }
}
