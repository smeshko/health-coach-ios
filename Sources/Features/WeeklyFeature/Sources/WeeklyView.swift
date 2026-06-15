import BriefRepository
import ComposableArchitecture
import DesignSystem
import DomainModels
import Foundation
import SwiftUI

/// The "This Week" tab's root view (the 2026-06-10 design — `Week · Exercise.png` / `This Week — Alt
/// States.png`): the "This Week" title + the week-range subtitle ("Jun 1 – 7 · a menu, not a schedule",
/// or "easy on purpose" on a deload week), the Exercise | Nutrition `SegTabs` toggle, and an **exhaustive**
/// switch over `store.weeklyState` (no `default:`) so Phases 9.2/9.3 add *content* to the `ready` branch
/// without ever missing a lifecycle render path. The `ready` Exercise arm shows the collapsible "The plan
/// this week" narrative card (the `.plan` slice via the shared `NarrativeRenderer`) + the week-rhythm
/// dot-row; the 9.2 session groups and 9.3 nutrition plug into the marked seams.
///
/// A pure state renderer — it does **not** self-trigger the load (`.task`); the tab attaches that
/// (TASK-007), keeping this view (and its snapshots) deterministic.
public struct WeeklyView: View {
  @Bindable var store: StoreOf<WeeklyFeature>
  @Dependency(\.calendar) var calendar

  public init(store: StoreOf<WeeklyFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
        switch store.weeklyState {
        case .idle, .loading:
          WeeklyHeader(subtitle: nil, cachedLabel: nil)
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.top, CoachSpacing.space2xl)
        case let .error(error):
          WeeklyHeader(subtitle: nil, cachedLabel: nil)
          WeeklyErrorContent(display: Self.errorDisplay(for: error)) { store.send(.retryTapped) }
        case let .ready(plan, freshness):
          WeeklyHeader(
            subtitle: subtitle(for: plan),
            cachedLabel: freshness == .cached ? cachedLabel(plan.generatedAt) : nil
          )
          SegTabs(selection: Binding(
            get: { store.selectedSection == .nutrition ? .nutrition : .exercise },
            set: { store.send(.sectionSelected($0 == .nutrition ? .nutrition : .exercise)) }
          ))
          WeeklyReadyContent(store: store, plan: plan)
        }
      }
      .padding(CoachSpacing.spaceLg)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(.coachBackground)
  }

  /// "Jun 1 – 7 · a menu, not a schedule" (deload → "… · easy on purpose"). The week range is the plan's
  /// `weekStart` … +6 days in the Europe/Sofia frame; `en_US_POSIX` keeps it deterministic for snapshots.
  private func subtitle(for plan: WeeklyPlan) -> String {
    "\(weekRange(plan.weekStart)) · \(WeeklyFeature.scheduleFraming(deload: plan.budgets.deload))"
  }

  private func weekRange(_ weekStart: Date) -> String {
    let end = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "MMM d"
    let startStr = formatter.string(from: weekStart)
    let sameMonth = calendar.isDate(weekStart, equalTo: end, toGranularity: .month)
    formatter.dateFormat = sameMonth ? "d" : "MMM d"
    return "\(startStr) – \(formatter.string(from: end))"
  }

  /// "Cached — as of 07:30" — the cached-plan freshness label (PRD §8.2).
  private func cachedLabel(_ generatedAt: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "HH:mm"
    return "Cached — as of \(formatter.string(from: generatedAt))"
  }

  /// Maps a typed `BriefError` onto the `DesignSystem` `ErrorDisplay` boundary (DisplayLabel.swift: "the
  /// feature error-presenter maps … onto this at the boundary") so a raw enum key never reaches the view.
  /// Kept byte-identical to `TodayView.errorDisplay(for:)` so the two features never diverge (Epic 05's
  /// `ErrorPresenter` will later unify them).
  static func errorDisplay(for error: BriefError) -> ErrorDisplay {
    switch error {
    case .syncRequired, .insufficientData: .unknown
    case .transientGenerationFailed: .briefGenerationFailed
    case .validation: .validationError
    case .serverError: .internalError
    case .unauthorized: .unauthorized
    }
  }
}

// MARK: - Shell chrome

/// The screen header: the large "This Week" title, the week-range subtitle (deload-aware), and the
/// "Cached — as of …" freshness line when a `.cached` plan is served.
private struct WeeklyHeader: View {
  let subtitle: String?
  let cachedLabel: String?

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      Text("This Week")
        .font(.coachText3xl)
        .foregroundStyle(.coachForeground)
      if let subtitle {
        Text(subtitle)
          .font(.coachTextMd)
          .foregroundStyle(.coachForegroundMuted)
      }
      if let cachedLabel {
        Text(cachedLabel)
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundSubtle)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Ready content

/// The `ready` content under the Exercise | Nutrition toggle: the Exercise arm carries the plan card + the
/// week-rhythm dot-row (+ the 9.2 session-group seam); the Nutrition arm is the 9.3 seam (empty here).
private struct WeeklyReadyContent: View {
  @Bindable var store: StoreOf<WeeklyFeature>
  let plan: WeeklyPlan

  var body: some View {
    switch store.selectedSection {
    case .exercise:
      VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
        PlanCard(store: store, narrative: plan.narrative, deload: plan.budgets.deload)
        if let rhythm = store.rhythm {
          WeekRhythmRow(days: rhythm.days)
            .padding(CoachSpacing.spaceLg)
            .background(CardSurface())
        }

        // MARK: - Phase 9.2 core/extra sessions
      }
    case .nutrition:
      // MARK: - Phase 9.3 weekly nutrition

      Color.clear.frame(height: 0)
    }
  }
}

/// The collapsible "The plan this week" narrative card (`Week · Exercise.png`): an icon + title + chevron
/// header (tapping toggles `isPlanCardExpanded`); when expanded, the `.plan` slice of the plan's narrative
/// (the feature filters — `NarrativeRenderer` never self-filters, 5.4) renders verbatim. The deload icon
/// treatment is a calm moon (warning tone), not an alarming badge.
private struct PlanCard: View {
  @Bindable var store: StoreOf<WeeklyFeature>
  let narrative: [NarrativeSection]
  let deload: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      Button { store.send(.planCardToggled) } label: {
        HStack(spacing: CoachSpacing.spaceSm) {
          Image(systemName: deload ? "moon.fill" : "calendar")
            .font(.coachTextSm)
            .foregroundStyle((deload ? Tone.warning : Tone.accent).foreground)
            .frame(width: Metrics.iconCircle, height: Metrics.iconCircle)
            .background(Circle().fill((deload ? Tone.warning : Tone.accent).fill))
          Text("The plan this week")
            .font(.coachTextMd)
            .fontWeight(.semibold)
            .foregroundStyle(.coachForeground)
          Spacer(minLength: CoachSpacing.spaceSm)
          Image(systemName: "chevron.right")
            .font(.coachTextSm)
            .foregroundStyle(.coachForegroundMuted)
            .rotationEffect(.degrees(store.isPlanCardExpanded ? 90 : 0))
        }
      }
      .buttonStyle(.coachPressable)

      if store.isPlanCardExpanded {
        NarrativeRenderer(narrative.filter { $0.type == .plan })
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(CoachSpacing.spaceLg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(CardSurface())
    .coachAnimation(.disclosure, value: store.isPlanCardExpanded)
  }

  private enum Metrics {
    static let iconCircle: CGFloat = 32
  }
}

/// The error state — friendly copy from the `DesignSystem` `ErrorDisplay` boundary + Retry.
private struct WeeklyErrorContent: View {
  let display: ErrorDisplay
  let onRetry: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      Banner(
        icon: "exclamationmark.triangle",
        tone: .negative,
        title: "Couldn't load this week",
        message: display.label
      )
      SecondaryButton("Retry", icon: "arrow.clockwise", action: onRetry)
    }
  }
}

/// The shared "This Week" card surface — a rounded `.coachSurface` rect with a hairline border.
private struct CardSurface: View {
  var body: some View {
    RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
      .fill(.coachSurface)
      .overlay(
        RoundedRectangle(cornerRadius: CoachRadius.card, style: .continuous)
          .stroke(.coachBorder, lineWidth: 1)
      )
  }
}
