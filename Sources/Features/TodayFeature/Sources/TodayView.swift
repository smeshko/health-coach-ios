import BriefRepository
import ComposableArchitecture
import DesignSystem
import DomainModels
import Foundation
import SwiftUI
import SyncRepository

/// The Today tab's root view (the 2026-06-10 shell — `Today · Exercise.png` / `Today · Nutrition.png`):
/// the "Today" title + Europe/Sofia date subtitle + the "● Synced …" pill, the Exercise | Nutrition
/// segmented toggle, then an **exhaustive** switch over `store.briefState` (no `default:`) — so the
/// 8.2/8.3/8.4 phases add *content* to the `ready` branch without ever missing a lifecycle render path.
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
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
        if !store.briefState.isIdle {
          TodayHeader(dateSubtitle: dateSubtitle, syncedLabel: syncedLabel)
          TodaySectionToggle(store: store)
        }

        switch store.briefState {
        case .idle:
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, CoachSpacing.spaceLg)
        case .syncing:
          TodayLoadingContent(message: "Syncing your health data…")
        case .generating:
          TodayLoadingContent(message: "Building today's brief…")
        case .syncFailed:
          TodaySyncFailedContent { store.send(.retryTapped) }
        case let .error(error):
          TodayBriefErrorContent(display: errorDisplay(for: error)) { store.send(.retryTapped) }
        case let .ready(brief, freshness):
          TodayReadyContent(
            store: store,
            cachedLabel: freshness == .cached ? cachedLabel(brief.generatedAt) : nil
          )
        }
      }
      .padding(CoachSpacing.spaceLg)
      .frame(maxWidth: .infinity, alignment: .leading)
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
  case .syncRequired, .insufficientData, .mappingFailed: .unknown
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

/// The Exercise | Nutrition segmented toggle, bound to `selectedSection` (sends `.sectionSelected`).
private struct TodaySectionToggle: View {
  @Bindable var store: StoreOf<TodayFeature>

  var body: some View {
    SegTabs(
      selection: Binding(
        get: { store.selectedSection == .exercise ? .exercise : .nutrition },
        set: { store.send(.sectionSelected($0 == .exercise ? .exercise : .nutrition)) }
      )
    )
  }
}

// MARK: - Lifecycle states

/// A centered spinner + message — the `.syncing` / `.generating` loading states (PRD §6/§8.2).
private struct TodayLoadingContent: View {
  let message: String

  var body: some View {
    VStack(spacing: CoachSpacing.spaceMd) {
      ProgressView()
      Text(message)
        .font(.coachTextMd)
        .foregroundStyle(.coachForegroundMuted)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, CoachSpacing.spaceLg)
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

/// The `ready` content area: the cached-freshness label, the check-in section, and the 8.2/8.3/8.4 seam
/// placeholders. The readiness gauge (8.2), session card (8.3), and nutrition (8.4) fill the seams later;
/// the check-in's final placement is an open design note (kept here as planned).
private struct TodayReadyContent: View {
  @Bindable var store: StoreOf<TodayFeature>
  let cachedLabel: String?

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      if let cachedLabel {
        Text(cachedLabel)
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundSubtle)
      }

      switch store.selectedSection {
      case .exercise:
        // MARK: - Phase 8.2 readiness

        // MARK: - Phase 8.3 session

        CheckInSection(store: store.scope(state: \.checkIn, action: \.checkIn))

        if store.offerRefresh {
          SecondaryButton("Refresh brief", icon: "arrow.clockwise") { store.send(.refreshTapped) }
        }
      case .nutrition:
        // MARK: - Phase 8.4 nutrition

        Text("Nutrition")
          .font(.coachTextMd)
          .foregroundStyle(.coachForegroundMuted)
      }
    }
  }
}

/// The morning check-in (PRD §7.2) restyled to `1 · Daily Check-in.png`: a "DAILY CHECK-IN" eyebrow,
/// "How are you today?" title + subtitle, a card with two Yes/No rows (helper copy) + the knee-pain
/// dot-stepper & severity badge, a "Save & build today's brief" button, and a "Last saved <time>"
/// footer. `kneePain` edits route through `kneePainChanged` (clamped) — out-of-range is impossible
/// (DECISIONS #2). The footer time is formatted in the Europe/Sofia frame so snapshots stay deterministic.
private struct CheckInSection: View {
  @Bindable var store: StoreOf<CheckInComponent>
  @Dependency(\.calendar) var calendar

  var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        Text("DAILY CHECK-IN")
          .font(.coachText2xs)
          .tracking(0.4)
          .foregroundStyle(.coachForegroundMuted)
        Text("How are you today?")
          .font(.coachText2xl)
          .foregroundStyle(.coachForeground)
        Text("Three quick taps. Edit and resubmit anytime.")
          .font(.coachTextMd)
          .foregroundStyle(.coachForegroundMuted)
      }

      VStack(spacing: CoachSpacing.spaceMd) {
        CheckInQuestionRow(
          title: "Any gut-flare signs today?",
          helper: "Bloating, cramps or urgency",
          isOn: Binding(get: { store.giSymptoms }, set: { store.send(.giSymptomsToggled($0)) })
        )
        Rectangle().fill(.coachBorder).frame(height: 1)
        CheckInQuestionRow(
          title: "Feeling ill or feverish?",
          helper: "Sore throat, chills, fever",
          isOn: Binding(get: { store.illness }, set: { store.send(.illnessToggled($0)) })
        )
        Rectangle().fill(.coachBorder).frame(height: 1)
        VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
              Text("Knee pain")
                .font(.coachTextLg)
                .foregroundStyle(.coachForeground)
              Text("0 = none · 10 = worst")
                .font(.coachTextSm)
                .foregroundStyle(.coachForegroundMuted)
            }
            Spacer(minLength: CoachSpacing.spaceSm)
            Pill(PainSeverity.badge(for: store.kneePain), tone: .warning)
          }
          DotStepper(
            value: Binding(get: { store.kneePain }, set: { store.send(.kneePainChanged($0)) })
          )
        }
      }
      .padding(CoachSpacing.spaceMd)
      .background(RoundedRectangle(cornerRadius: CoachRadius.card).fill(.coachSurface))

      VStack(spacing: CoachSpacing.spaceSm) {
        PrimaryButton("Save & build today's brief", isLoading: store.saveStatus == .saving) {
          store.send(.saveTapped)
        }
        if let savedAt = store.lastSavedAt {
          HStack(spacing: CoachSpacing.space2xs) {
            Image(systemName: "checkmark.circle")
            Text("Last saved \(savedTime(savedAt)) · tap any answer to edit")
          }
          .font(.coachTextXs)
          .foregroundStyle(.coachForegroundSubtle)
          .frame(maxWidth: .infinity)
        }
      }
    }
    .task { await store.send(.task).finish() }
  }

  /// "7:02 AM" in the Europe/Sofia frame (the pinned `\.calendar`); `en_US_POSIX` keeps it deterministic.
  private func savedTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
  }
}

/// One Yes/No question row in the check-in card — a title + helper line on the left, a `YesNoToggle` on
/// the trailing edge (`1 · Daily Check-in.png`).
private struct CheckInQuestionRow: View {
  let title: String
  let helper: String
  @Binding var isOn: Bool

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        Text(title)
          .font(.coachTextLg)
          .foregroundStyle(.coachForeground)
        Text(helper)
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundMuted)
      }
      Spacer(minLength: CoachSpacing.spaceSm)
      YesNoToggle(isOn: $isOn)
    }
  }
}

private extension BriefViewState {
  var isIdle: Bool {
    if case .idle = self { return true }
    return false
  }
}
