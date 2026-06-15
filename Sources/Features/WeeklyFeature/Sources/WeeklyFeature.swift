import BriefRepository
import CoachCore
import ComposableArchitecture
import DomainModels
import Foundation
import ProfileRepository
import Sharing

/// The "This Week" tab's root reducer (ARCHITECTURE §4.5/§8/§11, PRD §7.5) — the menu-with-budgets weekly
/// plan screen (the 2026-06-10 design iteration). It owns the universal `WeeklyViewState` lifecycle (the
/// single source of truth, DECISIONS #1) and the client-side new-ISO-week detection (§17.2) that triggers
/// the get-or-cache weekly fetch. The per-ISO-week cache itself lives in `BriefRepositoryLive` (D9 / 4.2) —
/// the feature always calls `weeklyBrief(isoWeek: nil, refresh: false)` on appear and lets the repo decide
/// fetch-vs-serve (DECISIONS #4); the new-week watermark drives the *moment* + the freshness label, not the
/// call. The 9.2 core/extra session groups + targets and the 9.3 weekly nutrition + adherence plug into
/// stable seams under `ready`.
///
/// **Feature dependency rule (§3):** imports only the repo **interfaces** (`BriefRepository` /
/// `ProfileRepository`, via `@Dependency`) + `DesignSystem` + `DomainModels` + `CoachCore` +
/// `ComposableArchitecture` (+ `Sharing` for the persisted watermark) — never a `*Live`, data-source
/// client, `WireModels`, GRDB, or HealthKit.
@Reducer
public struct WeeklyFeature {
  @ObservableState
  public struct State: Equatable {
    /// The screen lifecycle — the one source of truth (DECISIONS #1). No sibling `isLoading`/`error`
    /// bools; the enum is exhaustive. (The `rhythm` child + the `selectedSection`/`isPlanCardExpanded` UI
    /// flags land in TASK-004, and the 9.2/9.3 child slots as their phases land.)
    public var weeklyState: WeeklyViewState = .idle
    /// The persisted new-ISO-week watermark (DECISIONS #2) — the canonical `YYYY-Www` of the last week we
    /// successfully resolved a plan for. **Feature-local persisted state** (read by no other feature),
    /// using `@Shared(.appStorage)` purely as the TCA-native UserDefaults primitive — not a cross-feature
    /// reactive channel (so it sits outside §17.1's OPEN-1 gate; DECISIONS #2). Drives the "new week
    /// moment" + the freshness label; it never *gates* the fetch (the repo owns the cache, DECISIONS #4).
    ///
    /// Key is dotless (`weeklyLastSeenISOWeek`, not the plan's `weekly.lastSeenISOWeek`): swift-sharing
    /// rejects `.` for efficient key-value observation, and the dot was only namespacing cosmetics for a
    /// brand-new key with no prior persisted data — the watermark semantics are unchanged.
    @Shared(.appStorage("weeklyLastSeenISOWeek")) public var lastSeenISOWeek: String?
    /// The five-zone bpm map (`ProfileRepository.zones()`), resolved once by the fetch effect and handed to
    /// 9.2's pure rows so a "Zone N · bpm" line resolves (DECISIONS #4, cross-plan with 9.2). `nil` until
    /// the fetch lands (or if it fails — a non-fatal degrade: the rows omit the bpm line).
    public var zones: Zones?
    /// The week rhythm (the dot-row), derived once from the `ready` plan's suggested sessions. `nil` until a
    /// plan resolves.
    public var rhythm: WeekRhythmComponent.State?
    /// The Exercise | Nutrition segmented toggle (local UI state) — the shared `SegTabs` selection. 9.2's
    /// session groups render under `.exercise`, 9.3's nutrition under `.nutrition`.
    public var selectedSection: WeeklySection = .exercise
    /// The "The plan this week" narrative card's chevron (local UI state) — expanded by default.
    public var isPlanCardExpanded: Bool = true
    /// The "Do these — Core" group chevron (Phase 9.2, local UI state) — expanded by default. Pure UI,
    /// held outside `WeeklyViewState`, so it survives a re-supplied plan (a refreshed week).
    public var isCoreExpanded: Bool = true
    /// The "Optional — Extras" group chevron (Phase 9.2, local UI state) — expanded by default.
    public var isExtrasExpanded: Bool = true

    public init(
      weeklyState: WeeklyViewState = .idle,
      zones: Zones? = nil,
      rhythm: WeekRhythmComponent.State? = nil,
      selectedSection: WeeklySection = .exercise,
      isPlanCardExpanded: Bool = true,
      isCoreExpanded: Bool = true,
      isExtrasExpanded: Bool = true
    ) {
      self.weeklyState = weeklyState
      self.zones = zones
      self.rhythm = rhythm
      self.selectedSection = selectedSection
      self.isPlanCardExpanded = isPlanCardExpanded
      self.isCoreExpanded = isCoreExpanded
      self.isExtrasExpanded = isExtrasExpanded
    }
  }

  public enum Action {
    /// Sent on tab appear (`task`/`onAppear`) — runs the get-or-cache fetch (`refresh: false`, DECISIONS #4).
    case task
    /// Manual refresh from `.ready` — debounced, then forces a network regeneration (`refresh: true`).
    case refreshTapped
    /// Retry from the `.error` terminal — re-runs the `refresh: false` fetch.
    case retryTapped
    /// The Exercise | Nutrition toggle — pure UI, flips `selectedSection`.
    case sectionSelected(WeeklySection)
    /// The "The plan this week" card chevron — pure UI, flips `isPlanCardExpanded`.
    case planCardToggled
    /// The "Do these — Core" group header — pure UI, flips `isCoreExpanded` (Phase 9.2).
    case coreGroupToggled
    /// The "Optional — Extras" group header — pure UI, flips `isExtrasExpanded` (Phase 9.2).
    case extrasGroupToggled
    /// Internal — fired once the refresh debounce window elapses; sets `.loading` + runs the `refresh: true`
    /// fetch. (Loading is delayed to here so a rapid double-tap doesn't flash a loading screen per tap.)
    case refreshRequested
    /// Internal — the resolved plan. Lands `.ready(plan, freshness)` + the derived rhythm + the watermark
    /// **immediately** (before optional zones), so a slow profile read never blocks the primary plan
    /// (review #2 / the TodayFeature 12.1 render-then-hydrate pattern).
    case weeklyResolved(DomainModels.WeeklyPlan)
    /// Internal — the (non-fatal) HR zones, hydrated into `state.zones` **after** the plan renders. A nil
    /// (a throwing/absent read) is a silent degrade — the rows omit the bpm line; a prior non-nil map is kept.
    case zonesResolved(Zones?)
    /// Internal — the fetch failed; lands the terminal `.error` (a non-`BriefError` throw is mapped upstream).
    case weeklyFailed(BriefError)
  }

  /// Cancellation namespace. `.weeklyFetch` owns the get-or-cache `.run` (`cancelInFlight` — a stale fetch
  /// can't land after a newer request, §11); `.refreshDebounce` owns the debounced refresh window.
  public enum CancelID: Hashable, Sendable { case weeklyFetch, refreshDebounce }

  /// The manual-refresh debounce window (PRD §8.6 / §11). A named constant so tests advance a `TestClock`
  /// exactly past it; production injects the real `\.continuousClock`.
  static let refreshDebounceDuration: Duration = .milliseconds(300)

  @Dependency(\.briefRepository) var briefRepository
  @Dependency(\.profileRepository) var profileRepository
  @Dependency(\.continuousClock) var clock

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task, .retryTapped:
        // The appear / retry path is always `refresh: false` (DECISIONS #4) — the repo serves cache or
        // generates; the feature must NOT branch on `isNewWeek` to choose `refresh: true`.
        state.weeklyState = .loading
        return fetchEffect(refresh: false)

      case .refreshTapped:
        // Debounce (sleep + cancelInFlight — the canonical TCA idiom): a second rapid tap cancels the
        // first sleep, so only the last fires `refreshRequested` (which sets `.loading` + the `refresh:
        // true` fetch).
        return .run { [clock] send in
          try await clock.sleep(for: Self.refreshDebounceDuration)
          await send(.refreshRequested)
        }
        .cancellable(id: CancelID.refreshDebounce, cancelInFlight: true)

      case .refreshRequested:
        state.weeklyState = .loading
        return fetchEffect(refresh: true)

      case let .sectionSelected(section):
        state.selectedSection = section
        return .none

      case .planCardToggled:
        state.isPlanCardExpanded.toggle()
        return .none

      case .coreGroupToggled:
        state.isCoreExpanded.toggle()
        return .none

      case .extrasGroupToggled:
        state.isExtrasExpanded.toggle()
        return .none

      case let .weeklyResolved(plan):
        // Render the plan + derived rhythm immediately (before optional zones). The `cached` flag drives
        // the freshness label (PRD §8.2) — made truthful by the scoped `WeeklyPlanPolicy` amendment (a
        // local-store hit is stamped `cached == true`).
        state.rhythm = WeekRhythmComponent.rhythm(from: plan)
        state.weeklyState = .ready(plan, plan.cached ? .cached : .fresh)
        recordSeenWeek(&state, isoWeek: plan.isoWeek)
        return .none

      case let .zonesResolved(zones):
        // Merge — a failed/absent read (nil) leaves any prior map in place (mirrors TodayFeature's
        // `mergeZones`); never clobbers good zones with nil.
        if let zones { state.zones = zones }
        return .none

      case let .weeklyFailed(error):
        state.weeklyState = .error(error)
        return .none
      }
    }
  }

  /// The single cancellable get-or-cache fetch. Resolves `zones()` first (non-fatal, deterministic order so
  /// the exhaustive `TestStore` receives `zonesResolved` then `weeklyResponse`), then `weeklyBrief(nil,
  /// refresh)`. A `BriefError` lands the typed terminal; a propagated non-`BriefError` (e.g. a 401, which
  /// 4.x says is **not** a `BriefError`) is mapped to a retryable `.transientGenerationFailed` so the
  /// screen never wedges on `.loading` (global 401→Connect routing stays AppFeature's job, §13/D13).
  /// `cancelInFlight` cancels an earlier run; a cancelled run's `await send` is dropped by TCA, so no stale
  /// `.ready`/`.error` lands.
  private func fetchEffect(refresh: Bool) -> Effect<Action> {
    .run { [briefRepository, profileRepository] send in
      // Zones starts **concurrently** with the plan, but the plan renders the moment it resolves — the
      // optional, non-fatal zones await is moved OFF the critical path (review #2 / TodayFeature 12.1
      // render-then-hydrate): a slow/hung profile read can never block `.ready`. A cancelled run aborts
      // before sending the plan.
      async let zonesResult = try? await profileRepository.zones()
      do {
        try Task.checkCancellation()
        let plan = try await briefRepository.weeklyBrief(nil, refresh)
        await send(.weeklyResolved(plan))
        // Hydrate zones afterward (a throw → nil, a silent degrade). This await is past the `.ready`
        // render, so a parked zones leaves the plan visible.
        await send(.zonesResolved(zonesResult))
      } catch is CancellationError {
        return
      } catch let error as BriefError {
        await send(.weeklyFailed(error))
      } catch {
        await send(.weeklyFailed(.transientGenerationFailed))
      }
    }
    .cancellable(id: CancelID.weeklyFetch, cancelInFlight: true)
  }
}

/// The Exercise | Nutrition segmented toggle's selection (the 2026-06-10 shell). Top-level (not nested in
/// `WeeklyFeature`) to stay within the 1-level type-nesting lint rule, mirroring `TodaySection`.
public enum WeeklySection: Equatable, Sendable { case exercise, nutrition }

extension WeeklyFeature {
  /// The week-shape framing in the header subtitle — the calm deload phrasing vs the default "menu, not a
  /// schedule" (authored UX chrome gated on `deload`; the recovery *prose* is the server's `plan`
  /// narrative, never authored here). The deload treatment is a tone, not an alarming badge.
  static func scheduleFraming(deload: Bool) -> String {
    deload ? "easy on purpose" : "a menu, not a schedule"
  }
}

// MARK: - New-ISO-week detection (§17.2, DECISIONS #2/#3)

/// Format an `ISOWeek` as the canonical `YYYY-Www` string (zero-padded week, e.g. `2026-W03`). Mirrors
/// 4.2's `BriefRepositoryLive.isoWeekKey` so the feature's key byte-matches the server-stamped
/// `plan.isoWeek` (the post-fetch watermark round-trip holds); `CoachCore.ISOWeek` ships no `wireString`
/// and CoachCore stays out of scope, so this is a `WeeklyFeature`-local helper (DECISIONS #3).
func isoWeekKey(_ week: ISOWeek) -> String {
  String(format: "%04d-W%02d", week.year, week.week)
}

extension WeeklyFeature {
  /// The current Europe/Sofia ISO week as the canonical `YYYY-Www` — computed from `ISOWeek.current`,
  /// which reads the pinned `@Dependency(\.calendar)`/`(\.date)` (§17.2).
  var currentISOWeekKey: String { isoWeekKey(ISOWeek.current) }

  /// "New week" = the current key differs from the persisted watermark (a nil watermark is always new).
  /// Drives the §11 step-4 host trigger + the freshness moment — **not** the `refresh` flag of the appear
  /// call (which is always `false`, DECISIONS #4).
  func isNewWeek(_ state: State) -> Bool {
    currentISOWeekKey != (state.lastSeenISOWeek ?? "")
  }

  /// Record a just-resolved plan's ISO week as "seen" (DECISIONS #2) so subsequent opens the same week
  /// are not "new". Written on a successful `.ready`.
  func recordSeenWeek(_ state: inout State, isoWeek: String) {
    state.$lastSeenISOWeek.withLock { $0 = isoWeek }
  }
}
