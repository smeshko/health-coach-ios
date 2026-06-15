import DomainModels
import SwiftUI

/// The week's rhythm at a glance (the 2026-06-10 "This Week" design): the M T W T F S S letter row with one
/// colored dot per day connected by a thin baseline, above a "● Hard · ● Easy · ○ Rest" legend. Two cues
/// per dot: **color** = the day's character (terracotta Hard / teal Easy / a hollow grey Rest ring) and
/// **fill** = the tier (a filled disc when a *core* session sits that day, an outlined ring when only
/// *extras* do). Letters + the legend keep color from being the sole signal (PRD §9.4).
///
/// A pure presentation component — the caller derives the seven `Day` values (Mon…Sun) from the plan's
/// suggested sessions; this view renders whatever it is given. It assumes a `.coachSurface` container (the
/// "This Week" card) — the outlined dots mask the baseline with that color.
public struct WeekRhythmRow: View {
  /// One day's rhythm cue. `hard`/`easy` carry `core` (a filled disc) vs not (an outlined ring); `rest` is
  /// an empty grey ring.
  public enum Day: Sendable, Equatable, Hashable {
    case hard(core: Bool)
    case easy(core: Bool)
    case rest

    var tone: Tone? {
      switch self {
      case .hard: .negative
      case .easy: .accent
      case .rest: nil
      }
    }

    var isFilled: Bool {
      switch self {
      case let .hard(core), let .easy(core): core
      case .rest: false
      }
    }

    var isRest: Bool {
      if case .rest = self { true } else { false }
    }
  }

  let days: [Day]

  /// `days` is the Mon…Sun rhythm (seven entries — paired positionally with `Weekday.allCases`).
  public init(days: [Day]) {
    self.days = days
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
      VStack(spacing: CoachSpacing.spaceXs) {
        ZStack {
          Rectangle()
            .fill(.coachBorder)
            .frame(height: Metrics.line)
            .padding(.horizontal, CoachSpacing.spaceLg)
          HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
              Dot(day: day).frame(maxWidth: .infinity)
            }
          }
        }
        HStack(spacing: 0) {
          ForEach(Array(Weekday.allCases.enumerated()), id: \.offset) { index, weekday in
            Text(weekday.shortLabel)
              .font(.coachTextSm)
              .fontWeight(isRest(index) ? .regular : .semibold)
              .foregroundStyle(isRest(index) ? .coachForegroundSubtle : .coachForeground)
              .frame(maxWidth: .infinity)
          }
        }
      }
      Legend()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func isRest(_ index: Int) -> Bool {
    days.indices.contains(index) ? days[index].isRest : true
  }
}

/// One dot: a filled disc (core), an outlined ring (extra), or a hollow grey ring (rest). The interior is
/// filled with the surface color so the connecting baseline doesn't show through an outlined ring.
private struct Dot: View {
  let day: WeekRhythmRow.Day
  var size: CGFloat = Metrics.dot

  var body: some View {
    let color = day.tone?.foreground ?? .coachForegroundSubtle
    Circle()
      .fill(day.isFilled ? color : Color.coachSurface)
      .overlay(
        Circle().strokeBorder(color, lineWidth: day.isFilled ? 0 : Metrics.ring)
      )
      .frame(width: size, height: size)
  }
}

/// The "● Hard · ● Easy · ○ Rest" legend — a sample dot + label per character.
private struct Legend: View {
  var body: some View {
    HStack(spacing: CoachSpacing.spaceLg) {
      LegendItem(day: .hard(core: true), label: "Hard")
      LegendItem(day: .easy(core: true), label: "Easy")
      LegendItem(day: .rest, label: "Rest")
    }
  }
}

private struct LegendItem: View {
  let day: WeekRhythmRow.Day
  let label: String

  var body: some View {
    HStack(spacing: CoachSpacing.spaceXs) {
      Dot(day: day, size: Metrics.legendDot)
      Text(label)
        .font(.coachTextSm)
        .foregroundStyle(.coachForegroundMuted)
    }
  }
}

private enum Metrics {
  static let dot: CGFloat = 16
  static let legendDot: CGFloat = 12
  static let ring: CGFloat = 2
  static let line: CGFloat = 1.5
}
