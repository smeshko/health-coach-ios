import ComposableArchitecture
import DomainModels
import Foundation
import HealthKitClient
import ProfileRepository
import SyncRepository
import TokenClient

/// The You-tab root reducer (ARCHITECTURE §4.5 / §10). Created minimal in Phase 7.4 (the `tokenReset`
/// delegate seam + a `#if DEBUG` DEV section); **expanded in Phase 10.2** with the production CONNECTION
/// / APPLE HEALTH / PROFILE sections — read-only display slices loaded once on `onAppear` from the
/// repository/data-source **interfaces** (DECISIONS #3/#5). The REMINDERS section is Phase 10.3. The
/// `#if DEBUG` DEV slice (dev menu + log viewer) is retained unchanged.
@Reducer
public struct SettingsFeature {
  /// Delegate actions the shell (`MainTabs` → `AppFeature`) listens for. `tokenReset` asks the root to
  /// clear the session and return to onboarding. It is fired both by the DEBUG dev menu's reset action
  /// and by the production **Re-connect** row (DECISIONS #2 — the same §13 route a 401 takes); no
  /// parallel `reconnectRequested` seam is added.
  public enum Delegate: Equatable {
    case tokenReset
  }

  @ObservableState
  public struct State: Equatable {
    public var load: LoadState = .idle
    public var connection: ConnectionState = .init()
    public var health: HealthKitStatusState = .init()
    public var lastSync: LastSyncState = .init()
    public var constants: ConstantsState = .init()

    // Load-gate bookkeeping: each of the four `onAppear` effects flips its flag; `settleLoad` sets
    // `load = .loaded` once all four are resolved and none failed — so the transition lives in one
    // place and is independent of which effect resolves last (the merged effects arrive out of order).
    var connectionResolved = false
    var lastSyncResolved = false
    var constantsResolved = false
    var healthResolved = false

    #if DEBUG
      /// The presented DEBUG dev menu (DEV section → "Dev Menu" row). Absent in RELEASE.
      @Presents public var devMenu: DevMenuFeature.State?
    #endif
    public init() {}
  }

  public enum Action {
    case onAppear
    case connectionLoaded(String?)
    case lastSyncLoaded(Date?)
    case constantsLoaded(Result<DomainModels.Profile, ProfileLoadFailure>)
    case healthStatusLoaded(HealthKitStatusState)
    case reconnectTapped
    case openHealthSettingsTapped
    case delegate(Delegate)
    #if DEBUG
      case devMenuTapped
      case devMenu(PresentationAction<DevMenuFeature.Action>)
    #endif
  }

  @Dependency(\.profileRepository) var profileRepository
  @Dependency(\.syncRepository) var syncRepository
  @Dependency(\.healthKitClient) var healthKitClient
  @Dependency(\.tokenClient) var tokenClient
  @Dependency(\.openURL) var openURL

  private enum CancelID { case load }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        switch state.load {
        case .loading:
          // A first load is already in flight — don't disturb it.
          return .none
        case .loaded:
          // Re-entering the tab: refresh only the last-sync time — the one slice that goes stale after
          // each sync (a cheap watermark read). Token/constants rarely change, and the HK probe is
          // intentionally NOT repeated here: it's an unbounded HealthKit history read (review #1.2/#1.3),
          // so it runs only on the first load. (HK-status refresh after a permission change is a deferred
          // follow-up tied to a bounded presence API.)
          return .run { [syncRepository] send in
            await send(.lastSyncLoaded(try? await syncRepository.lastSync()))
          }
          .cancellable(id: CancelID.load, cancelInFlight: true)
        case .idle, .failed:
          // First load (or a retry after failure): load all four slices, including the one-time HK probe.
          state.load = .loading
          state.connectionResolved = false
          state.lastSyncResolved = false
          state.constantsResolved = false
          state.healthResolved = false
          // Read all four slices CONCURRENTLY (`async let`), then send the result actions in a FIXED
          // order so the merged load is deterministic to assert in a TestStore (the slices still load in
          // parallel — only the delivery order is pinned).
          return .run { [tokenClient, syncRepository, profileRepository, healthKitClient] send in
            async let token = try? await tokenClient.read()
            async let lastSyncDate = try? await syncRepository.lastSync()
            async let constants = loadConstants(profileRepository)
            async let health = loadHealthStatus(healthKitClient)
            await send(.connectionLoaded(await token))
            await send(.lastSyncLoaded(await lastSyncDate))
            await send(.constantsLoaded(await constants))
            await send(.healthStatusLoaded(await health))
          }
          .cancellable(id: CancelID.load, cancelInFlight: true)
        }

      case let .connectionLoaded(token):
        // Never store the full bearer token — only the last-4 masked suffix (DECISIONS #4).
        if let token, !token.isEmpty {
          state.connection.status = .connected(tokenSuffix: String(token.suffix(4)))
        } else {
          state.connection.status = .notConnected
        }
        state.connectionResolved = true
        settleLoad(&state)
        return .none

      case let .lastSyncLoaded(date):
        state.lastSync.lastSyncAt = date
        state.lastSyncResolved = true
        settleLoad(&state)
        return .none

      case let .constantsLoaded(.success(profile)):
        state.constants = ConstantsState(
          age: profile.athlete.age,
          zones: profile.zones,
          restingHrBpm: profile.thresholds.rhrBaseline,
          hrvBaselineMs: profile.thresholds.hrvBaselineMs,
          recomputeNoticeWeek: profile.meta.constantsRecomputedWeek
        )
        state.constantsResolved = true
        settleLoad(&state)
        return .none

      case .constantsLoaded(.failure):
        state.constantsResolved = true
        state.load = .failed
        return .none

      case let .healthStatusLoaded(status):
        state.health = status
        state.healthResolved = true
        settleLoad(&state)
        return .none

      case .reconnectTapped:
        // Clear the bearer token BEFORE bubbling the reset (mirroring the dev-menu reset, review #1.1):
        // AppFeature's tokenReset handler only routes to onboarding and assumes the You tab already
        // cleared the session, so without this a restart in the reconnect window would resurrect the
        // stale token. Then reuse the existing reserved seam (DECISIONS #2) → the parent routes to .connect.
        return .run { [tokenClient] send in
          try? await tokenClient.clear()
          await send(.delegate(.tokenReset))
        }

      case .openHealthSettingsTapped:
        return .run { [openURL] _ in
          guard let url = URL(string: "x-apple-health://") else { return }
          await openURL(url)
        }

      case .delegate:
        return .none

      #if DEBUG
        case .devMenuTapped:
          state.devMenu = DevMenuFeature.State()
          return .none
        case .devMenu(.presented(.delegate(.tokenReset))):
          // The dev menu cleared the bearer token → dismiss the sheet and bubble the route-to-onboarding
          // up to the shell (navigation lives at the root — D7).
          state.devMenu = nil
          return .send(.delegate(.tokenReset))
        case .devMenu:
          return .none
      #endif
      }
    }
    #if DEBUG
    .ifLet(\.$devMenu, action: \.devMenu) { DevMenuFeature() }
    #endif
  }

  /// Sets `load = .loaded` once every slice has resolved and none failed. Order-independent: each of the
  /// four load result handlers calls this after flipping its own slice's resolved flag.
  private func settleLoad(_ state: inout State) {
    guard state.load != .failed else { return }
    if state.connectionResolved, state.lastSyncResolved, state.constantsResolved, state.healthResolved {
      state.load = .loaded
    }
  }
}

/// Loads the profile constants as a `Result`, mapping any repository error to the feature-local opaque
/// `ProfileLoadFailure` (a free function so the `async let` in `onAppear` captures no `self`).
private func loadConstants(
  _ repository: ProfileRepository
) async -> Result<DomainModels.Profile, SettingsFeature.ProfileLoadFailure> {
  do {
    return .success(try await repository.profile())
  } catch {
    return .failure(.failed)
  }
}

/// Probes HealthKit for the shared/missing status. When HK is unavailable, returns the all-missing
/// state **without** a delta read. Otherwise reduces a `deltaSamples(since: .distantPast)` probe per
/// category (emptiness ⇒ not shared — HK masks read grants, §3.3/6.3). A free function so the
/// `async let` in `onAppear` captures no `self`.
private func loadHealthStatus(
  _ client: HealthKitClient
) async -> SettingsFeature.HealthKitStatusState {
  guard client.isHealthDataAvailable() else {
    return HealthStatusInference.healthStatus(from: .empty, status: [:], available: false)
  }
  let set = (try? await client.deltaSamples(.distantPast)) ?? .empty
  return HealthStatusInference.healthStatus(from: set, status: client.authorizationStatus(), available: true)
}
