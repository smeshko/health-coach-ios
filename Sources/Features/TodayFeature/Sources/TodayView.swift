import BriefRepository
import ComposableArchitecture
import DesignSystem
import DomainModels
import Foundation
import SessionFeature
import SwiftUI
import SyncRepository

/// The Today tab's root view (the 2026-06-10 shell — `Today · Exercise.png` / `Today · Nutrition.png`):
/// the "Today" title + Europe/Sofia date subtitle + the "● Synced …" pill, over an **exhaustive** switch
/// over `store.briefState` (no `default:`) — so the 8.2/8.3/8.4 phases add *content* to the `ready`
/// branch without ever missing a lifecycle render path. The morning **check-in is a full cover presented
/// on top** of that brief content (the `ZStack`'s upper layer, the `.checkInRequired` gate —
/// `1 · Daily Check-in.png`): while it's up the opaque cover hides the brief, and saving dismisses it
/// to reveal the loaded brief — so the check-in never renders inline alongside the exercise/nutrition view.
/// The Exercise | Nutrition segmented toggle (the `SegTabs` primitive) sits atop the `ready` content
/// (`TodayReadyContent`), switching the brief between the exercise and nutrition sections.
///
/// All chrome is `DesignSystem` tokens/primitives; the brief-error copy comes from the `DesignSystem`
/// `ErrorDisplay` boundary (the feature maps the typed `BriefError` onto it). The sync-failed state shows
/// the PRD §8.2 block-and-retry copy ("couldn't sync — check connection"); the typed `SyncError` is held
/// in state for the Epic 05 `ErrorPresenter`.
public struct TodayView: View {
  @Bindable var store: StoreOf<TodayFeature>
  @Dependency(\.date) var date
  @Dependency(\.calendar) var calendar

  public init(store: StoreOf<TodayFeature>) {
    self.store = store
  }

  public var body: some View {
    // The check-in is **not** a lifecycle branch — it presents as a full cover **on top** of the brief
    // (the `ZStack`'s upper layer). While the gate is up, the opaque cover hides the exercise/nutrition
    // brief entirely (the 2026-06-10 design: the check-in is its own screen, `1 · Daily Check-in.png`).
    ZStack {
      Group {
        switch store.briefState {
        // Idle + the two loading states render chrome-free and centered — the `2 ·`/`3 · Loading` mockups
        // have no header/toggle. Content states (below) carry them via `TodayContentScroll`.
        case .idle:
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .checkInRequired:
          // The brief is gated behind the check-in, so it hasn't loaded yet — the base stays empty; the
          // check-in cover (below) is the entry screen on top.
          Color.clear
        // One branch for both loading states (not two `case`s) — a shared view identity is what lets the
        // ring's trim tween 0.3 → 0.7 and the spinners keep turning across the syncing→generating handoff.
        case .syncing, .generating:
          let generating = store.briefState == .generating
          SyncProgressView(
            progress: generating ? LoadingCopy.generatingProgress : LoadingCopy.syncingProgress,
            title: generating ? LoadingCopy.generatingTitle : LoadingCopy.syncingTitle,
            subtitle: generating ? LoadingCopy.generatingSubtitle : LoadingCopy.syncingSubtitle,
            steps: generating ? LoadingCopy.generatingSteps : LoadingCopy.syncingSteps
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .syncFailed:
          TodayContentScroll(dateSubtitle: dateSubtitle, syncedLabel: syncedLabel) {
            TodaySyncFailedContent { store.send(.retryTapped) }
          }
        case let .error(error):
          TodayContentScroll(dateSubtitle: dateSubtitle, syncedLabel: syncedLabel) {
            TodayBriefErrorContent(display: errorDisplay(for: error)) { store.send(.retryTapped) }
          }
        case let .ready(brief, freshness):
          TodayContentScroll(dateSubtitle: dateSubtitle, syncedLabel: syncedLabel) {
            TodayReadyContent(
              store: store,
              brief: brief,
              cachedLabel: freshness == .cached ? cachedLabel(brief.generatedAt) : nil
            )
          }
        }
      }

      // The morning check-in presented **on top** of the brief — an opaque full cover, so while the gate
      // is up nothing from the exercise/nutrition brief shows through. Saving re-enters the sync→brief
      // chain, which flips `briefState` off `.checkInRequired` and dismisses the cover to reveal the brief.
      if store.briefState == .checkInRequired {
        TodayContentScroll(dateSubtitle: dateSubtitle, syncedLabel: syncedLabel) {
          CheckInSection(store: store.scope(state: \.checkIn, action: \.checkIn))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.coachBackground)
      }
    }
    .background(.coachBackground)
  }

  /// "Friday, June 5" in the Europe/Sofia frame (the pinned `\.calendar`/`\.date`). `en_US_POSIX` keeps
  /// it deterministic for snapshots.
  private var dateSubtitle: String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEEE, MMMM d"
    return formatter.string(from: date.now)
  }

  /// "Synced 2m ago" — `nil` (pill hidden) until the orchestration records `lastSyncedAt`.
  private var syncedLabel: String? {
    guard let last = store.lastSyncedAt else { return nil }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return "Synced \(formatter.localizedString(for: last, relativeTo: date.now))"
  }

  /// "as of 07:45" — the cached-brief freshness label (PRD §8.2).
  private func cachedLabel(_ generatedAt: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "HH:mm"
    return "Cached — as of \(formatter.string(from: generatedAt))"
  }
}

/// Maps a typed `BriefError` onto the `DesignSystem` `ErrorDisplay` boundary (DisplayLabel.swift: "the
/// feature error-presenter maps … onto this at the boundary") so a raw enum key never reaches the view.
/// The refined per-code copy is Epic 05's `ErrorPresenter`; this is the closest existing vocabulary.
private func errorDisplay(for error: BriefError) -> ErrorDisplay {
  switch error {
  case .syncRequired, .insufficientData: .unknown
  case .transientGenerationFailed: .briefGenerationFailed
  case .validation: .validationError
  case .serverError: .internalError
  case .unauthorized: .unauthorized
  }
}

// MARK: - Shell chrome

/// The screen header: large "Today" title, the Europe/Sofia date subtitle, and the trailing synced pill.
private struct TodayHeader: View {
  let dateSubtitle: String
  let syncedLabel: String?

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        Text("Today")
          .font(.coachText3xl)
          .foregroundStyle(.coachForeground)
        Text(dateSubtitle)
          .font(.coachTextMd)
          .foregroundStyle(.coachForegroundMuted)
      }
      Spacer(minLength: CoachSpacing.spaceSm)
      if let syncedLabel {
        Pill(syncedLabel, tone: .positive, leading: .dot)
      }
    }
  }
}

// MARK: - Loaded-content frame

/// The loaded-content frame: the screen header above the state's content, in a scroll view. The
/// idle/loading states render chrome-free + centered instead (the `2 ·`/`3 · Loading` mockups have no
/// header), so the header lives here rather than unconditionally. The Exercise|Nutrition toggle is NOT
/// part of this frame — only the `ready` content carries it (no brief → no sections).
private struct TodayContentScroll<Content: View>: View {
  let dateSubtitle: String
  let syncedLabel: String?
  @ViewBuilder let content: Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
        TodayHeader(dateSubtitle: dateSubtitle, syncedLabel: syncedLabel)
        content
      }
      .padding(CoachSpacing.spaceLg)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// MARK: - Lifecycle states

/// The designed loading copy + step lists for `.syncing` / `.generating` (`2 ·`/`3 · Loading` mockups),
/// factored out so the two states read declaratively. `.generating` shows step 1 done, step 2 active.
private enum LoadingCopy {
  static let syncingProgress = 0.3
  static let syncingTitle = "Syncing health data…"
  static let syncingSubtitle = "Pulling sleep, HRV and resting heart rate from Apple Health."
  static var syncingSteps: [SyncStep] {
    [
      SyncStep(id: 0, label: "Syncing health data", state: .active),
      SyncStep(id: 1, label: "Building today's brief", state: .pending),
    ]
  }

  static let generatingProgress = 0.7
  static let generatingTitle = "Building today's brief…"
  static let generatingSubtitle =
    "Weighing your recovery, sleep and yesterday's load. This takes a few seconds."
  static var generatingSteps: [SyncStep] {
    [
      SyncStep(id: 0, label: "Health data synced", state: .done),
      SyncStep(id: 1, label: "Building today's brief", state: .active),
    ]
  }
}

/// The distinct block-and-retry sync-failure state (PRD §8.2 / D23) — "couldn't sync — check connection".
private struct TodaySyncFailedContent: View {
  let onRetry: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      Banner(
        icon: "wifi.exclamationmark",
        tone: .negative,
        title: "Couldn't sync",
        message: "Check your connection and try again."
      )
      SecondaryButton("Retry", icon: "arrow.clockwise", action: onRetry)
    }
  }
}

/// The brief-generation error state — friendly copy from the `DesignSystem` boundary + Retry.
private struct TodayBriefErrorContent: View {
  let display: ErrorDisplay
  let onRetry: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      Banner(
        icon: "exclamationmark.triangle",
        tone: .negative,
        title: "Something went wrong",
        message: display.label
      )
      SecondaryButton("Retry", icon: "arrow.clockwise", action: onRetry)
    }
  }
}

/// The `ready` content area: the cached-freshness label, then either the **exercise** arm — the
/// **readiness gauge** (Phase 8.3) above the **forced-REST vs normal-session** switch (`TodaySessionMode`,
/// Phase 8.3) — or the **nutrition** arm (Phase 8.5). The check-in is **not** here: it presents as a full
/// cover on top of this view (`TodayView`'s `ZStack`), so a loaded brief never shows the check-in inline
/// (the 2026-06-10 design — the check-in is its own screen). The Exercise|Nutrition `SegTabs` toggle is
/// wired through `selectedSection`/`sectionSelected`.
private struct TodayReadyContent: View {
  @Bindable var store: StoreOf<TodayFeature>
  let brief: DomainModels.DailyBrief
  let cachedLabel: String?

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      // The Exercise | Nutrition switcher (`Today · Exercise.png` / `Today · Nutrition.png`) — sits above
      // the brief content, only in `ready` (no brief → no sections). Selection lives in `selectedSection`;
      // taps route through `.sectionSelected` so the reducer owns the toggle (exhaustively testable).
      SegTabs(selection: Binding(
        get: { store.selectedSection == .nutrition ? .nutrition : .exercise },
        set: { store.send(.sectionSelected($0 == .nutrition ? .nutrition : .exercise)) }
      ))

      if let cachedLabel {
        Text(cachedLabel)
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundSubtle)
      }

      switch store.selectedSection {
      case .exercise:
        // The readiness gauge (Phase 8.3), scoped so its "why" toggle persists. The summary narrative
        // ("Good morning …") is parent-filtered and passed in.
        if let readinessStore = store.scope(state: \.readiness, action: \.readiness) {
          ReadinessComponentView(
            store: readinessStore,
            summary: brief.narrative.filter { $0.type == .summary }
          )
        }

        // Forced-REST vs the ordinary session are **distinct rendered states** (ARCHITECTURE §8 / §1
        // principle #6 / PRD §7.4.2), chosen by the authoritative `safetyGate.triggered` signal. The
        // switch is **exhaustive** (no `default:`), mirroring the `briefState` discipline.
        switch TodaySessionMode.from(brief) {
        case let .forcedRest(gate, override):
          // The dedicated calm forced-REST screen — read-only override session, no swap/skip/alternatives.
          // `zoneRange` is nil here: the `rest`/`mobility` overrides carry no `zoneTarget` (→ no chip), and
          // `TodayFeature` does not yet hold the profile zones (Phase 8.4 wires zone resolution for the
          // normal session); an `active_recovery` override's Z1 chip is reconciled when that lands.
          SafetyRestView(
            store: Store(
              initialState: SafetyRestComponent.State(
                gate: gate, overrideSession: override, zoneRange: nil
              )
            ) { SafetyRestComponent() },
            narrative: brief.narrative.filter { $0.type == .session || $0.type == .caution }
          )
        case .normal:
          // The promoted `SessionFeature` (Phase 8.4) renders the displayed session through the
          // `SessionCard` with the inline SWAP-TO list + the warm skip affordance. The parent hydrates
          // `state.session` exactly on the untripped (`.normal`) path, so the scope is non-nil here.
          if let sessionStore = store.scope(state: \.session, action: \.session) {
            SessionFeatureView(store: sessionStore)
          }
        }
      case .nutrition:
        // MARK: - Phase 8.5 nutrition

        // The TODAY'S FUEL panel + COACH NOTE, then the yesterday recap / no-food empty state — co-equal
        // with the workout (PRD §7.4.4 / §6 principle 4). Both are render-only sub-components constructed
        // inline from the loaded brief (the `SafetyRestComponent` precedent), so they hold no parent state
        // and need no reducer scope.
        NutritionView(
          store: Store(initialState: NutritionComponent.State(brief: brief)) { NutritionComponent() }
        )
        YesterdayIntakeView(
          store: Store(
            initialState: YesterdayIntakeComponent.State(intakeYesterday: brief.intakeYesterday)
          ) { YesterdayIntakeComponent() }
        )
      }
    }
  }
}
