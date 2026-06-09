import ComposableArchitecture
import HealthKitClient

/// The HealthKit priming + degraded step of `OnboardingFeature` (ARCHITECTURE §4.5 / §10, PRD §5
/// FR-ONB-2 / §8.5). Explains each Apple-Health signal before the unskippable system sheet, requests
/// authorization, and — because HealthKit deliberately masks whether a **read** grant succeeded — infers
/// "what's missing" from **empty delta reads**, never from the status map (DECISIONS #2). A full grant
/// lands `.granted` → `delegate(.finished)`; partial/declined/unavailable lands `.degraded` with a
/// non-blocking Continue (degraded is never a hard block — epic AC-2).
///
/// **Phase 7.3 / TASK-001:** the state machine + pure transitions only. The authorize + degraded-probe
/// effects (`connectTapped` → `requestAuthorization` → `deltaSamples` inference) land in TASK-002.
@Reducer
public struct HealthKitPriming {
  /// The step's exhaustive phase. `.checking` is the post-grant degraded-probe window; `.degraded`
  /// carries the inferred summary. Exhaustive so a `TestStore` can assert every transition.
  public enum PrimingPhase: Equatable, Sendable {
    case priming
    case authorizing
    case checking
    case granted
    case degraded(DegradedSummary)
  }

  /// The degraded-screen payload: which rows are missing (inferred from empty delta slices), the single
  /// banner signal (top-priority missing row), and the corroborating status hint (the read-auth map,
  /// used only to sharpen wording — never to decide "missing"; DECISIONS #2).
  public struct DegradedSummary: Equatable, Sendable {
    public var missing: Set<PrimingRow>
    public var bannerSignal: PrimingRow?
    public var statusHint: [HealthDataCategory: HealthAuthorizationStatus]

    public init(
      missing: Set<PrimingRow>,
      bannerSignal: PrimingRow?,
      statusHint: [HealthDataCategory: HealthAuthorizationStatus] = [:]
    ) {
      self.missing = missing
      self.bannerSignal = bannerSignal
      self.statusHint = statusHint
    }
  }

  @ObservableState
  public struct State: Equatable {
    public var phase: PrimingPhase
    /// The best-effort read-auth hint (corroboration / `.healthDataUnavailable` short-circuit only).
    public var statusHint: [HealthDataCategory: HealthAuthorizationStatus]
    /// The rows inferred missing from the empty-delta probe (drives the degraded view).
    public var missingRows: Set<PrimingRow>

    public init(
      phase: PrimingPhase = .priming,
      statusHint: [HealthDataCategory: HealthAuthorizationStatus] = [:],
      missingRows: Set<PrimingRow> = []
    ) {
      self.phase = phase
      self.statusHint = statusHint
      self.missingRows = missingRows
    }
  }

  /// The only thing this step tells `OnboardingFeature`: "the HK step is done" (granted, or degraded +
  /// Continue). The parent translates it into `OnboardingFeature.Delegate.connected`, which flips
  /// `AppFeature` to `.main` (§10 / D7 — navigation owned by the parent).
  public enum Delegate: Equatable { case finished }

  public enum Action {
    /// "Connect Apple Health" — runs the availability gate → `requestAuthorization` → degraded probe
    /// (the effect lands in TASK-002; here it only enters `.authorizing`).
    case connectTapped
    /// `requestAuthorization` resolved — success carries the corroborating status hint; failure (sheet
    /// dismissed/denied) short-circuits to fully degraded without a probe (TASK-002).
    case authorizationResponse(Result<[HealthDataCategory: HealthAuthorizationStatus], any Error>)
    /// The one-shot `deltaSamples(since: .distantPast)` probe result — reduced to missing rows via the
    /// empty-slice inference (TASK-002).
    case degradedProbeResponse(Result<HealthSampleSet, any Error>)
    /// Degraded "Open Health settings" deep link (`x-apple-health://`) — wired to `openURL` in TASK-002.
    case openHealthSettingsTapped
    /// Degraded "Continue" — proceeds anyway (non-blocking).
    case continueTapped
    case delegate(Delegate)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .connectTapped:
        // Pure transition; the authorize/probe effect lands in TASK-002.
        state.phase = .authorizing
        return .none

      case .continueTapped:
        // Degraded → proceed anyway (not a hard block — epic AC-2).
        return .send(.delegate(.finished))

      case .authorizationResponse, .degradedProbeResponse, .openHealthSettingsTapped, .delegate:
        // Effects land in TASK-002.
        return .none
      }
    }
  }
}
