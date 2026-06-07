import DomainModels
import SwiftUI

/// Renders the ordered `[NarrativeSection]` **exactly as received** — no reordering, no authored prose
/// (principle #1, §9.1). Each section is styled by its `NarrativeType` (summary/plan lead, session
/// instructional, nutrition distinct, `caution` set-apart + soft accent + **non-alarming**, never the
/// red band token, §9.2) and its body is rendered with basic markdown (inline emphasis + simple lists).
public struct NarrativeRenderer: View {
  public let sections: [NarrativeSection]

  public init(sections: [NarrativeSection]) {
    self.sections = sections
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space16) {
      ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
        sectionView(section)
      }
    }
  }

  @ViewBuilder
  private func sectionView(_ section: NarrativeSection) -> some View {
    let style = NarrativeStyle(section.type)
    VStack(alignment: .leading, spacing: CoachSpacing.space8) {
      HStack(spacing: CoachSpacing.space6) {
        if let icon = style.iconName {
          Image(systemName: icon).foregroundStyle(style.accent)
        }
        Text(section.heading).font(style.headingFont).foregroundStyle(style.headingColor)
      }
      bodyView(section.body)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(style.isCard ? CoachSpacing.space16 : 0)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.md)
        .fill(style.isCard ? style.fill : Color.clear)
    )
    .overlay(
      RoundedRectangle(cornerRadius: CoachRadius.md)
        .stroke(style.isCard ? style.accent.opacity(0.4) : Color.clear, lineWidth: 1)
    )
  }

  /// The body — split into lines so simple `-`/`*`/`1.` bullets render as a list (SwiftUI `Text`
  /// markdown does not render block lists); each line's inline emphasis is parsed with whitespace
  /// preserved, falling back to the raw string on a parse failure so the body is never lost.
  @ViewBuilder
  private func bodyView(_ text: String) -> some View {
    let lines = text.components(separatedBy: "\n")
    VStack(alignment: .leading, spacing: CoachSpacing.space4) {
      ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
        lineView(line)
      }
    }
  }

  @ViewBuilder
  private func lineView(_ raw: String) -> some View {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty {
      Spacer().frame(height: CoachSpacing.space4)
    } else if let item = listItem(trimmed) {
      HStack(alignment: .firstTextBaseline, spacing: CoachSpacing.space6) {
        Text("•").foregroundStyle(CoachColor.foregroundMuted)
        Text(inlineMarkdown(item)).font(CoachFont.body).foregroundStyle(CoachColor.foregroundMuted)
      }
    } else {
      Text(inlineMarkdown(trimmed)).font(CoachFont.body).foregroundStyle(CoachColor.foregroundMuted)
    }
  }

  /// The content of a `-`/`*`/`1.` list line, or `nil` if the line is not a list item.
  private func listItem(_ line: String) -> String? {
    if line.hasPrefix("- ") || line.hasPrefix("* ") {
      return String(line.dropFirst(2))
    }
    return orderedListItem(line)
  }

  /// The content after an ordered `N. ` prefix (any number of leading digits), or `nil`.
  private func orderedListItem(_ line: String) -> String? {
    var digits = ""
    var index = line.startIndex
    while index < line.endIndex, line[index].isNumber {
      digits.append(line[index])
      index = line.index(after: index)
    }
    guard !digits.isEmpty else { return nil }
    let rest = line[index...]
    guard rest.hasPrefix(". ") else { return nil }
    return String(rest.dropFirst(2))
  }

  private func inlineMarkdown(_ string: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    return (try? AttributedString(markdown: string, options: options)) ?? AttributedString(string)
  }
}

/// Per-`NarrativeType` styling. `caution` is the only carded/accented one (a calm set-apart note, soft
/// amber — never the red band token); the rest are plain in-flow prose with lead headings.
private struct NarrativeStyle {
  let headingFont: Font
  let headingColor: Color
  let accent: Color
  let fill: Color
  let isCard: Bool
  let iconName: String?

  init(_ type: NarrativeType) {
    switch type {
    case .summary, .plan:
      headingFont = CoachFont.screenTitle
      headingColor = CoachColor.foreground
      accent = CoachColor.accent
      fill = .clear
      isCard = false
      iconName = nil
    case .session, .nutrition:
      headingFont = CoachFont.cardHeadline
      headingColor = CoachColor.foreground
      accent = CoachColor.accent
      fill = .clear
      isCard = false
      iconName = nil
    case .caution:
      headingFont = CoachFont.cardHeadline
      headingColor = CoachColor.warning
      accent = CoachColor.warning
      fill = CoachColor.warningSoft
      isCard = true
      iconName = "info.circle.fill"
    }
  }
}
