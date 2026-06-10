import ComposableArchitecture
import Foundation

/// The Today tab's root reducer (ARCHITECTURE §4.5, PRD §6/§8.1) — the hero "daily brief" screen. It owns
/// the universal `BriefViewState` lifecycle (the single source of truth, DECISIONS #1) and — from
/// TASK-003 — the morning orchestration effect (check-in → sync → daily brief, sync strictly before the
/// brief). The 8.2/8.3/8.4 sub-sections plug into stable seams under `ready` without restructuring this
/// parent; the lifecycle case set is fixed now (later phases add *content*, not new cases).
///
/// **Feature dependency rule (§3):** imports only the repo **interfaces** (`BriefRepository`/
/// `SyncRepository`/`CheckInRepository`, via `BriefViewState` + `@Dependency` later) + `DesignSystem` +
/// `DomainModels` + `CoachCore` + `ComposableArchitecture` — never a `*Live`, data-source client,
/// `WireModels`, GRDB, or HealthKit.
@Reducer
public struct TodayFeature {
  @ObservableState
  public struct State: Equatable {
    /// The screen lifecycle — the one source of truth (DECISIONS #1). No sibling `isLoading`/`error`
    /// bools; the enum is exhaustive.
    public var briefState: BriefViewState
    /// The morning check-in child (PRD §7.2). Always present; rendered in the `ready` branch.
    public var checkIn: CheckInComponent.State
    /// The 2026-06-10 shell's Exercise | Nutrition segmented toggle (local UI state). 8.2/8.3 render
    /// under `.exercise`, 8.4 under `.nutrition`.
    public var selectedSection: TodaySection
    /// Set by the orchestration on a successful `sync()` (TASK-003) — drives the header's relative
    /// "Synced 2m ago" pill via the CoachCore date dependency.
    public var lastSyncedAt: Date?

    public init(
      briefState: BriefViewState = .idle,
      checkIn: CheckInComponent.State = CheckInComponent.State(),
      selectedSection: TodaySection = .exercise,
      lastSyncedAt: Date? = nil
    ) {
      self.briefState = briefState
      self.checkIn = checkIn
      self.selectedSection = selectedSection
      self.lastSyncedAt = lastSyncedAt
    }
  }

  public enum Action {
    /// Sent by the host on app-open — drives the morning orchestration (TASK-003).
    case onAppOpen
    /// The Refresh affordance — a debounced re-run of the orchestration with `refresh: true` (TASK-004).
    case refreshTapped
    /// Retry from a `.syncFailed`/`.error` terminal — re-runs the full sync-first chain (TASK-003).
    case retryTapped
    /// The segmented toggle — pure UI, flips `selectedSection`.
    case sectionSelected(TodaySection)
    /// The morning check-in child's actions.
    case checkIn(CheckInComponent.Action)
  }

  /// Cancellation namespace. `.orchestration` owns the chained sync→brief `.run` (TASK-003); a new
  /// trigger (`onAppOpen`/`refreshTapped`/`retryTapped`) cancels it in-flight so a stale brief can't land
  /// after a newer request. `.refreshDebounce` owns the Refresh debounce window (TASK-004).
  public enum CancelID: Hashable, Sendable { case orchestration, refreshDebounce }

  public init() {}

  public var body: some ReducerOf<Self> {
    Scope(state: \.checkIn, action: \.checkIn) {
      CheckInComponent()
    }
    Reduce { state, action in
      switch action {
      case let .sectionSelected(section):
        state.selectedSection = section
        return .none
      case .onAppOpen, .refreshTapped, .retryTapped:
        // The orchestration + debounce land in TASK-003 / TASK-004.
        return .none
      case .checkIn:
        // The bubbled `.checkIn(.delegate(.checkInSaved))` → offer-Refresh handling lands in TASK-003.
        return .none
      }
    }
  }
}

/// The Exercise | Nutrition segmented toggle's selection (the 2026-06-10 shell). Top-level (not nested in
/// `TodayFeature`) to stay within the 1-level type-nesting lint rule.
public enum TodaySection: Equatable, Sendable { case exercise, nutrition }
