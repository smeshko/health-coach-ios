import APIClient
import ComposableArchitecture
import Foundation
import TokenClient

/// The Connect step's reducer (ARCHITECTURE §4.5 / §10, PRD §8.4 / FR-ONB-1): paste a bearer token,
/// validate it via `GET /probe`, and either keep it (success → advance) or clear it (failure → show the
/// error). Lives **inside** the `OnboardingFeature` target — it is composed only by `OnboardingFeature`'s
/// `.connect` step, never promoted (PLAN.md D5).
///
/// **Load-bearing ordering (DECISIONS 1):** `probe()` takes no token argument and reads the bearer from
/// `TokenClient` per request (§6.1/D12), so the candidate token **must** be written to the Keychain
/// *before* probing. On any failure the candidate is `clear()`ed, so an invalid token is shown without
/// being left stored.
@Reducer
public struct ConnectComponent {
  /// The single source of truth for the button/spinner/error — no boolean soup.
  public enum Validation: Equatable { case idle, validating, invalid }

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
    /// The view's Paste affordance. No clipboard `@Dependency` is pinned in the architecture yet
    /// (DECISIONS 4), so the view reads `UIPasteboard` directly and feeds `.tokenPasted`; this stays as
    /// an explicit no-op target for a future clipboard dependency.
    case pasteTapped
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
        // path (FR-ONB-1: no account/recovery flow).
        state.validation = .idle
        return .none

      case .pasteTapped:
        // No-op: the pasted string arrives via `.tokenPasted` from the view's `PasteButton`
        // (DECISIONS 4). Kept so the Paste affordance has a stable action target.
        return .none

      case let .tokenPasted(value):
        state.token = value
        state.validation = .idle
        return .none

      case .connectTapped:
        guard state.canSubmit else { return .none }
        state.validation = .validating
        let candidate = state.token.trimmingCharacters(in: .whitespacesAndNewlines)
        return .run { [tokenClient, apiClient] send in
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

      case .probeResponse(.success):
        // Probe returned without throwing → the token is valid (the `Bool` value is irrelevant). It
        // stays stored; tell the parent to advance.
        state.validation = .idle
        return .send(.delegate(.connected))

      case .probeResponse(.failure):
        // Any failure (401 → `APIError.unauthorized`, or a transport error): clear the just-written
        // candidate so no invalid token is left in the Keychain, and show the in-screen error. Do NOT
        // navigate — the §13 stream-driven 401 bounce is idempotent (already on Connect).
        state.validation = .invalid
        return .run { [tokenClient] _ in try? await tokenClient.clear() }

      case .delegate:
        return .none
      }
    }
  }
}
