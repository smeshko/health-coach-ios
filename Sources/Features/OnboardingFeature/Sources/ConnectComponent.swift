import APIClient
import ComposableArchitecture
import Foundation
import TokenClient

/// The Connect step's reducer (ARCHITECTURE §4.5 / §10, PRD §8.4 / FR-ONB-1): paste a bearer token,
/// validate it via `GET /probe`, and land on one of THREE outcomes: success → keep the token and
/// advance; 401 (`APIError.unauthorized`) → the token is wrong → clear it and show `.invalid`; any
/// other failure (transport/offline, decode, the unconfigured client) → the server never gave a
/// verdict → clear the candidate (restore-safety, see below) but show `.unreachable`, never "token
/// invalid". Lives **inside** the `OnboardingFeature` target — it is composed only by
/// `OnboardingFeature`'s `.connect` step, never promoted (PLAN.md D5).
///
/// **Load-bearing ordering (DECISIONS 1):** `probe()` takes no token argument and reads the bearer from
/// `TokenClient` per request (§6.1/D12), so the candidate token **must** be written to the Keychain
/// *before* probing. On EVERY failure the candidate is `clear()`ed — an unvalidated token left stored
/// would flip the next launch's restore to `.main`. `.unreachable` changes the presentation, not the
/// persistence.
///
/// **Stale-probe race closure:** the probe effect runs under `CancelID.probe`, and any field edit
/// (`binding`/`tokenPasted`) cancels it — a stale probe response can never arrive after the user moved
/// on, so a late transient failure cannot clear a NEWER candidate or masquerade as "invalid". The edit
/// arms also clear the (possibly just-written) candidate themselves, because cancelling the probe
/// suppresses the failure arm where the clear otherwise lives. That clear is registered under the SAME
/// cancel ID, so a re-tap cancels a pending clear before writing (a detached clear could interleave
/// write → clear → probe and 401 a valid token). Cancellation is cooperative: effect bodies lead with
/// `Task.checkCancellation()` so a cancelled-but-unstarted body cannot still run.
@Reducer
public struct ConnectComponent {
  /// The single source of truth for the button/spinner/error — no boolean soup. `.invalid` means the
  /// server REJECTED the token (401); `.unreachable` means the server never answered (transport,
  /// timeout, misconfigured base URL) — the token got no verdict.
  public enum Validation: Equatable { case idle, validating, invalid, unreachable }

  /// Single cancel ID for the probe effect AND the edit-triggered candidate clears — one in-flight
  /// operation at a time; each new one cancels its predecessor (`cancelInFlight: true`).
  private enum CancelID { case probe }

  @ObservableState
  public struct State: Equatable {
    /// The paste/edit field. Trimmed before it is written/probed (a pasted token often carries a
    /// trailing newline).
    public var token: String
    public var validation: Validation

    public init(token: String = "", validation: Validation = .idle) {
      self.token = token
      self.validation = validation
    }

    /// Connect is enabled only for a non-empty trimmed token that is not already validating — so a probe
    /// is never fired on an empty token (a guaranteed 401 round-trip).
    public var canSubmit: Bool {
      !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validation != .validating
    }
  }

  /// The only thing the child tells its parent (`OnboardingFeature`): "the token validated." The parent
  /// owns the step transition (TCA delegate pattern). Distinct from `OnboardingFeature.Delegate.connected`
  /// — see `OnboardingFeature`.
  public enum Delegate: Equatable { case connected }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case tokenPasted(String)
    case connectTapped
    /// Carries "probe returned without throwing" (success — the `Bool` value is irrelevant per §6/3.1)
    /// vs a thrown error (failure — 401 `APIError.unauthorized` or a transport error).
    case probeResponse(Result<Bool, any Error>)
    case delegate(Delegate)
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.tokenClient) var tokenClient

  public init() {}

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        // Any field edit clears a prior error back to idle — re-entry / re-paste is the only recovery
        // path (FR-ONB-1: no account/recovery flow). The edit also cancels any in-flight probe (the
        // stale-probe race closure) and clears the candidate the cancelled probe may have written —
        // cancellation suppresses the failure arm where the clear otherwise runs. Clearing when
        // nothing was written is a harmless no-op.
        state.validation = .idle
        return .run { [tokenClient] _ in
          try Task.checkCancellation()
          try? await tokenClient.clear()
        }
        .cancellable(id: CancelID.probe, cancelInFlight: true)

      case let .tokenPasted(value):
        state.token = value
        state.validation = .idle
        // Same cancel-probe + clear-candidate semantics as `.binding` — see above.
        return .run { [tokenClient] _ in
          try Task.checkCancellation()
          try? await tokenClient.clear()
        }
        .cancellable(id: CancelID.probe, cancelInFlight: true)

      case .connectTapped:
        guard state.canSubmit else { return .none }
        state.validation = .validating
        let candidate = state.token.trimmingCharacters(in: .whitespacesAndNewlines)
        return .run { [tokenClient, apiClient] send in
          // Cooperative cancellation guard: `cancelInFlight` above may have cancelled a PENDING edit
          // clear, and a later edit may cancel THIS task before it starts — never write a candidate
          // from an already-cancelled probe.
          try Task.checkCancellation()
          do {
            // DECISIONS 1: write the candidate FIRST so the transport can inject it as the bearer
            // header when `probe` runs.
            try await tokenClient.write(candidate)
            let succeeded = try await apiClient.probe()
            await send(.probeResponse(.success(succeeded)))
          } catch {
            await send(.probeResponse(.failure(error)))
          }
        }
        .cancellable(id: CancelID.probe, cancelInFlight: true)

      case .probeResponse(.success):
        // Probe returned without throwing → the token is valid (the `Bool` value is irrelevant). It
        // stays stored; tell the parent to advance.
        state.validation = .idle
        return .send(.delegate(.connected))

      case let .probeResponse(.failure(error)):
        // Discriminate the verdict: ONLY a 401 (`APIError.unauthorized`) means the server rejected the
        // token → `.invalid`. Every other failure (transport/offline, decode, the unconfigured
        // client's `.transport`) means the server never answered → `.unreachable` — reachability, not
        // a token verdict. BOTH arms clear the just-written candidate: an unvalidated token left in
        // the Keychain would flip the next launch's restore to `.main`. Do NOT navigate — the §13
        // stream-driven 401 bounce is idempotent (already on Connect). The clear runs under
        // `CancelID.probe` too, so a subsequent re-tap cancels it before writing (no stray clear can
        // interleave write → clear → probe).
        state.validation = error as? APIError == .unauthorized ? .invalid : .unreachable
        return .run { [tokenClient] _ in
          try Task.checkCancellation()
          try? await tokenClient.clear()
        }
        .cancellable(id: CancelID.probe, cancelInFlight: true)

      case .delegate:
        return .none
      }
    }
  }
}
