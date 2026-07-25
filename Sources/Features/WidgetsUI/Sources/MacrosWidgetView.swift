import DesignSystem
import DomainModels
import SwiftUI

/// The daily-macros widget view (Phase 21.3) — pure SwiftUI over a derived `MacrosWidgetState`.
/// Small: day-type badge + kcal/protein/carb targets; medium adds the fat range and hydration.
/// The yesterday footer renders only when intake exists (`vsTarget` % + protein hit marker) and
/// collapses without gaps when it doesn't. Layout/padding conventions match `SessionWidgetView`.
public struct MacrosWidgetView: View {
  /// The rendered family — home-screen small/medium only.
  public enum Layout: Sendable {
    case small, medium
  }

  let state: MacrosWidgetState
  let layout: Layout

  public init(state: MacrosWidgetState, layout: Layout) {
    self.state = state
    self.layout = layout
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      switch state {
      case let .macros(focus, yesterday):
        HStack(alignment: .firstTextBaseline) {
          WidgetEyebrow("TODAY'S FUEL")
          Spacer(minLength: CoachSpacing.spaceSm)
          DayTypeBadge(dayType: focus.dayType)
        }
        HStack(alignment: .lastTextBaseline, spacing: CoachSpacing.spaceXs) {
          Text(focus.caloriesKcal.formatted())
            .font(layout == .small ? .coachTextXl : .coachText2xl)
            .foregroundStyle(.coachForeground)
          Text("kcal")
            .font(.coachTextSm)
            .foregroundStyle(.coachForegroundMuted)
        }
        if layout == .small {
          Text("P \(focus.proteinG) g · C \(focus.carbsG) g")
            .font(.coachTextSm)
            .foregroundStyle(.coachForeground)
        } else {
          HStack(alignment: .top, spacing: CoachSpacing.spaceLg) {
            MacroStat(value: "\(focus.proteinG) g", name: "Protein")
            MacroStat(value: "\(focus.carbsG) g", name: "Carbs")
            MacroStat(
              value: RangeFormatter.string(low: focus.fatGLow, high: focus.fatGHigh, unit: "g"),
              name: "Fat"
            )
            MacroStat(
              value: RangeFormatter.string(
                low: focus.hydrationLLow, high: focus.hydrationLHigh, unit: "L"
              ),
              name: "Water"
            )
          }
          .padding(.top, CoachSpacing.space2xs)
        }
        Spacer(minLength: 0)
        if let yesterday {
          YesterdayFooter(vsTarget: yesterday)
        }
      case .stale:
        WidgetEyebrow("TODAY'S FUEL")
        Text("—")
          .font(.coachText3xl)
          .foregroundStyle(.coachForegroundSubtle)
        Text("No brief yet")
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundMuted)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(CoachSpacing.spaceMd)
  }
}

/// The day-type badge — the app's carb-cycling colors (hard→warning, moderate→accent, rest→subtle)
/// as a colored dot beside the `DayType` label, matching the `CarbCyclingPattern` legend convention.
private struct DayTypeBadge: View {
  let dayType: DayType

  var body: some View {
    HStack(spacing: CoachSpacing.space2xs) {
      Circle()
        .fill(dayType.badgeColor)
        .frame(width: 8, height: 8)
      Text(dayType.label)
        .font(.coachTextXs)
        .foregroundStyle(.coachForegroundMuted)
    }
  }
}

/// One target stat — value over a muted name (the medium family's row).
private struct MacroStat: View {
  let value: String
  let name: String

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      Text(value)
        .font(.coachTextMd)
        .foregroundStyle(.coachForeground)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(name)
        .font(.coachText2xs)
        .foregroundStyle(.coachForegroundMuted)
    }
  }
}

/// The yesterday recap footer — the wire calories % and the protein hit/missed marker, both read
/// verbatim from `vsTarget` (no client nutrition math, D4).
private struct YesterdayFooter: View {
  let vsTarget: IntakeVsTarget

  var body: some View {
    HStack(spacing: CoachSpacing.spaceXs) {
      Text("Yesterday")
        .font(.coachText2xs)
        .foregroundStyle(.coachForegroundSubtle)
      Text(vsTarget.caloriesPct.formatted(.percent.precision(.fractionLength(0))))
        .font(.coachTextXs)
        .foregroundStyle(.coachForegroundMuted)
      Image(systemName: vsTarget.proteinHit ? "checkmark.circle.fill" : "xmark.circle")
        .font(.coachTextXs)
        .foregroundStyle(vsTarget.proteinHit ? .coachPositive : .coachWarning)
      Text("protein")
        .font(.coachText2xs)
        .foregroundStyle(.coachForegroundSubtle)
    }
  }
}

private extension DayType {
  /// The day-type presentation color — the `CarbCyclingPattern` mapping (amber hard / accent
  /// moderate / subtle rest), duplicated here because that mapping is private to the composite.
  var badgeColor: Color {
    switch self {
    case .hard: .coachWarning
    case .moderate: .coachAccent
    case .rest: .coachForegroundSubtle
    }
  }
}
