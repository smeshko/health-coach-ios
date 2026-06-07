import SwiftUI

/// A tappable "+ quick add-on" row (e.g. foot prehab) — accent action icon + title + subtitle. The
/// icon stays `$accent` (not recolored to a status tone).
public struct PrehabAddon: View {
  public let title: String
  public let subtitle: String

  public init(title: String, subtitle: String) {
    self.title = title
    self.subtitle = subtitle
  }

  public var body: some View {
    HStack(spacing: CoachSpacing.space10) {
      Image(systemName: Icon.prehab.systemName)
        .font(.system(size: 18))
        .foregroundStyle(CoachColor.accent)
      VStack(alignment: .leading, spacing: CoachSpacing.space2) {
        Text(title).font(CoachFont.secondaryMeta).foregroundStyle(CoachColor.foreground)
        Text(subtitle).font(CoachFont.caption).foregroundStyle(CoachColor.foregroundMuted)
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, CoachSpacing.space10)
    .padding(.horizontal, CoachSpacing.space12)
    .background(RoundedRectangle(cornerRadius: CoachRadius.md).fill(CoachColor.background))
    .overlay(RoundedRectangle(cornerRadius: CoachRadius.md).stroke(CoachColor.border, lineWidth: 1))
  }
}
