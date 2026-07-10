import ComposableArchitecture
import Foundation
import HealthKitClient

/// The HealthKit priming + degraded step of `OnboardingFeature` (ARCHITECTURE §4.5 / §10, PRD §5
/// FR-ONB-2 / §8.5). Explains each Apple-Health signal before the unskippable system sheet, requests
/// authorization, and — because HealthKit deliberately masks whether a **read** grant succeeded — infers
/// "what's missing" from **empty delta reads**, never from the status map (DECISIONS #2). A full grant
/// lands `.granted` → `delegate(.finished)`; partial/declined/unavailable lands `.degraded` with a
/// non-blocking Continue (degraded is never a hard block — epic AC-2).
///
/// The degraded probe reads `HealthKitClient.deltaSamples(since: .distantPast)` **directly** (the feature
/// already imports the interface for auth — the §13/D12/§4.5 onboarding carve-out), **not** via
/// `SyncRepository`: the call is watermark-neutral (a passed-in far-past `Date`), and `SyncRepository`'s
/// `sync()` returns only counts, never the `HealthSampleSet` degraded inference needs (DECISIONS #2).
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

  /// The degraded-screen payload: which rows are missing (inferred from empty delta slices).
  public struct DegradedSummary: Equatable, Sendable {
    public var missing: Set<PrimingRow>

    public init(missing: Set<PrimingRow>) {
      self.missing = missing
    }
  }

  @ObservableState
  public struct State: Equatable {
    public var phase: PrimingPhase
    /// The rows inferred missing from the empty-delta probe (drives the degraded view).
    public var missingRows: Set<PrimingRow>

    public init(
      phase: PrimingPhase = .priming,
      missingRows: Set<PrimingRow> = []
    ) {
      self.phase = phase
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

  @Dependency(\.healthKitClient) var healthKitClient
  @Dependency(\.openURL) var openURL

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .connectTapped:
        state.phase = .authorizing
        return .run { [healthKitClient] send in
          // No HealthKit on this device (some iPads) → fully degraded, never touching the auth sheet or
          // the probe (DECISIONS #2: `.healthDataUnavailable` is degraded, not an error).
          guard healthKitClient.isHealthDataAvailable() else {
            await send(.authorizationResponse(.failure(HealthKitPrimingError.healthDataUnavailable)))
            return
          }
          do {
            try await healthKitClient.requestAuthorization()
            // The status map is captured only as a corroborating hint (HK masks read grants).
            await send(.authorizationResponse(.success(healthKitClient.authorizationStatus())))
          } catch {
            await send(.authorizationResponse(.failure(error)))
          }
        }

      case .authorizationResponse(.success):
        state.phase = .checking
        // One-shot, watermark-neutral presence probe since the far past — "is there any sample at all",
        // not a 30-day window, so an old-but-granted category still reads present (DECISIONS #2). Runs
        // under the dedicated `.presenceProbe()` bounds (365 rows/type ≈ a year of activity-summary
        // days, 10s timeout — the user is waiting): bounded, but presence semantics preserved.
        return .run { [healthKitClient] send in
          do {
            let samples = try await healthKitClient.deltaSamples(.presenceProbe())
            await send(.degradedProbeResponse(.success(samples)))
          } catch {
            await send(.degradedProbeResponse(.failure(error)))
          }
        }

      case .authorizationResponse(.failure):
        // A thrown auth error (sheet dismissed/denied) or `.healthDataUnavailable` leaves HK
        // indeterminate, so a follow-up probe is unreliable: go straight to fully degraded, no probe.
        // The degraded path never throws to the UI (epic AC-2 — not a hard block).
        return degrade(&state, missing: Set(PrimingRow.allCases))

      case let .degradedProbeResponse(.success(samples)):
        // "What's missing" is inferred from EMPTY delta slices, never the status map (DECISIONS #2).
        let missing = missingRows(from: samples)
        guard !missing.isEmpty else {
          state.missingRows = []
          state.phase = .granted
          return .send(.delegate(.finished))
        }
        return degrade(&state, missing: missing)

      case .degradedProbeResponse(.failure):
        // A post-grant probe failure must not crash the UI — treat as fully degraded.
        return degrade(&state, missing: Set(PrimingRow.allCases))

      case .openHealthSettingsTapped:
        return .run { [openURL] _ in
          guard let url = URL(string: "x-apple-health://") else { return }
          await openURL(url)
        }

      case .continueTapped:
        // Degraded → proceed anyway (not a hard block — epic AC-2).
        return .send(.delegate(.finished))

      case .delegate:
        return .none
      }
    }
  }

  /// Land the `.degraded` phase from an inferred missing-row set.
  private func degrade(_ state: inout State, missing: Set<PrimingRow>) -> Effect<Action> {
    state.missingRows = missing
    state.phase = .degraded(DegradedSummary(missing: missing))
    return .none
  }
}

/// HK has no read-permission failure of its own here; the only thrown signal we synthesize is
/// "no HealthKit on this device", which the reducer routes to the same fully-degraded state.
enum HealthKitPrimingError: Error, Equatable { case healthDataUnavailable }

/// Reduce a delta `HealthSampleSet` to the rows that are **conspicuously absent** — a row is missing when
/// **all** its categories returned zero samples (DECISIONS #2). Pure + feature-local (the grouping seam),
/// unit-tested directly. No `HealthSampleSet.isEmpty(for:)` helper exists on the Phase 3.3 payload, so
/// per-category emptiness is derived here.
func missingRows(from samples: HealthSampleSet) -> Set<PrimingRow> {
  Set(PrimingRow.allCases.filter { row in row.categories.allSatisfy { categoryIsEmpty($0, in: samples) } })
}

/// A category is empty when the delta set carries no sample for it: `workouts`/`activity` are not
/// `RecordType`-backed (their own arrays), every other category is empty when no `records` element
/// carries a `type` in that category's `RecordType` set (the Phase 3.3 category→`RecordType` mapping).
private func categoryIsEmpty(_ category: HealthDataCategory, in samples: HealthSampleSet) -> Bool {
  switch category {
  case .workouts: samples.workouts.isEmpty
  case .activity: samples.activity.isEmpty
  default:
    !samples.records.contains { category.recordTypes.contains($0.type) }
  }
}
