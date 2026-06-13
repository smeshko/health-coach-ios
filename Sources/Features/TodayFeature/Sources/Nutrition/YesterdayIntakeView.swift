import DesignSystem
import DomainModels
import SwiftUI

/// The yesterday-intake card (`Today · Nutrition.png`): the "YESTERDAY" eyebrow ("vs target" trailing on a
/// logged day), then either the recap — **calories %** (from `vsTarget.caloriesPct`) over a progress bar
/// with the logged kcal, a **protein hit/missed** marker (from `vsTarget.proteinHit`, the "✓ Floor hit"
/// chip), and water/fiber — or the calm **"No food logged yesterday"** empty state (`.empty`).
///
/// A **render-only** value-init view (no `@Reducer` ceremony): the parent constructs it from the loaded
/// brief's `intakeYesterday`. The only "logic" is a **pure presence check** in `init(intake:)`: a
/// whole-null intake maps to `.empty` (the first-class no-food state, §7.4.5/§8.5/§14); a present
/// `IntakeSummary` (even one whose macro totals are all nil) maps to `.logged` — the §5 distinction
/// (`IntakeSummary.required: [date, vsTarget]` — every total nullable, `vsTarget` not).
///
/// The calories % and the protein marker are read **verbatim from `vsTarget`** — no client nutrition math
/// (D4/principle #4). Nil macro totals are simply omitted (never `0`, never force-unwrapped). The empty
/// branch is a first-class state, not zeros and not an error (§7.4.5/§8.5/§14).
public struct YesterdayIntakeView: View {
  /// The recap vs the no-food empty state — 1-level nested (the type-nesting lint rule).
  enum DisplayState: Equatable, Sendable {
    case logged(DomainModels.IntakeSummary)
    case empty
  }

  /// `.logged(summary)` vs the no-food `.empty` — derived **once** from the optional in `init(intake:)` so
  /// the critical empty branch is a single typed value (tests assert it directly), never a view-only `nil`
  /// unwrap that could fall through to zeros.
  let display: DisplayState

  /// Map the optional to the display state: `nil → .empty`, `.some(summary) → .logged(summary)`. A pure
  /// presence check (no numeric math) — the §5 distinction: a present summary with all-nil totals is still
  /// `.logged` (its `vsTarget` recap renders; nil totals are simply omitted).
  public init(intake: DomainModels.IntakeSummary?) {
    display = intake.map(DisplayState.logged) ?? .empty
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      HStack(alignment: .firstTextBaseline) {
        Text("YESTERDAY")
          .font(.coachText2xs)
          .tracking(Metrics.eyebrowTracking)
          .foregroundStyle(.coachForegroundMuted)
        Spacer(minLength: CoachSpacing.spaceSm)
        if case .logged = display {
          Text("vs target")
            .font(.coachText2xs)
            .foregroundStyle(.coachForegroundSubtle)
        }
      }

      switch display {
      case let .logged(summary):
        LoggedRecap(summary: summary)
      case .empty:
        YesterdayEmptyState()
      }
    }
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
        .fill(.coachSurface)
        .overlay(
          RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
            .stroke(.coachBorder, lineWidth: 1)
        )
    )
  }
}

/// The logged recap — calories (% + bar + logged kcal), the protein hit/missed marker, water/fiber. All
/// numbers read straight from the domain; the % and the marker come from `vsTarget` (no client math). Each
/// nullable total renders only when present (never zeros, never a force-unwrap).
private struct LoggedRecap: View {
  let summary: DomainModels.IntakeSummary

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      // Calories: the wire % is the headline; the logged kcal is context (target is not on the summary —
      // deriving it would be client math, so it is not shown). The bar fills to the same wire %.
      VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
        HStack(alignment: .firstTextBaseline, spacing: CoachSpacing.spaceSm) {
          Text("Calories")
            .font(.coachTextMd)
            .foregroundStyle(.coachForeground)
          Spacer(minLength: CoachSpacing.spaceSm)
          if let kcal = summary.caloriesKcal {
            Text("\(kcal.formatted()) kcal")
              .font(.coachTextSm)
              .foregroundStyle(.coachForegroundMuted)
          }
          Text(Self.percentString(summary.vsTarget.caloriesPct))
            .font(.coachTextLg)
            .foregroundStyle(.coachAccent)
        }
        CalorieBar(fraction: summary.vsTarget.caloriesPct)
      }

      // Protein: the dot + grams (when present), and the hit/missed marker straight from `vsTarget`.
      HStack(alignment: .firstTextBaseline, spacing: CoachSpacing.spaceSm) {
        Circle()
          .fill(.coachAccent)
          .frame(width: Metrics.dot, height: Metrics.dot)
        Text("Protein")
          .font(.coachTextMd)
          .foregroundStyle(.coachForeground)
        if let protein = summary.proteinG {
          Text("\(protein) g")
            .font(.coachTextSm)
            .foregroundStyle(.coachForegroundMuted)
        }
        Spacer(minLength: CoachSpacing.spaceSm)
        if summary.vsTarget.proteinHit {
          Pill("Floor hit", tone: .positive, leading: .icon("checkmark"))
        } else {
          Pill("Missed", tone: .warning, leading: .icon("exclamationmark"))
        }
      }

      // Water + fiber — shown only when present (an absent total is omitted, not zeroed).
      if let waterFiber = Self.waterFiberLine(summary) {
        Text(waterFiber)
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundMuted)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// The wire calories ratio as an integer percent ("92%") — a display format of `vsTarget.caloriesPct`,
  /// not a computation (no target/logged division).
  private static func percentString(_ ratio: Double) -> String {
    ratio.formatted(.percent.precision(.fractionLength(0)))
  }

  /// "Water 2.4 L · Fiber 30 g" — only the present halves; `nil` when both are absent (no row).
  private static func waterFiberLine(_ summary: DomainModels.IntakeSummary) -> String? {
    var parts: [String] = []
    if let water = summary.waterL {
      parts.append("Water \(water.formatted(.number.precision(.fractionLength(1)))) L")
    }
    if let fiber = summary.fiberG {
      parts.append("Fiber \(fiber) g")
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }
}

/// The first-class "no food logged yesterday" empty state — a calm nudge, never zeros and never an error
/// (§7.4.5/§8.5/§14).
private struct YesterdayEmptyState: View {
  var body: some View {
    HStack(alignment: .top, spacing: CoachSpacing.spaceSm) {
      Image(systemName: "fork.knife")
        .font(.coachTextLg)
        .foregroundStyle(.coachForegroundSubtle)
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        Text("No food logged yesterday")
          .font(.coachTextMd)
          .foregroundStyle(.coachForeground)
        Text("Keep logging in your food app and yesterday's recap will show up here.")
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundMuted)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A thin continuous progress bar for the calories ratio — a sunken track with an accent fill clamped to
/// 0…1. Clamping is display safety (an over-target day reads as full), not nutrition math.
private struct CalorieBar: View {
  let fraction: Double

  var body: some View {
    GeometryReader { geometry in
      let clamped = min(max(fraction, 0), 1)
      ZStack(alignment: .leading) {
        Capsule().fill(.coachSurfaceSunken)
        Capsule()
          .fill(.coachAccent)
          .frame(width: geometry.size.width * clamped)
      }
    }
    .frame(height: Metrics.barHeight)
  }
}

/// Named constants — the eyebrow tracking, the protein dot, and the calorie-bar height.
private enum Metrics {
  static let eyebrowTracking: CGFloat = 0.4
  static let dot: CGFloat = 8
  static let barHeight: CGFloat = 8
}
