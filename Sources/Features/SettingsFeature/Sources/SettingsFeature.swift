import ComposableArchitecture
import DomainModels
import Foundation
import HealthKitClient
import NotificationClient
import ProfileRepository
import Sharing
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

    // Phase 10.3 reminders. `remindersEnabled` is the user's persisted **intent** (feature-local
    // appStorage; the key is dotless — swift-sharing rejects `.` for key-value observation, per the
    // WeeklyFeature precedent). `notificationAuthorization` mirrors the live OS status. The effective
    // toggle is `intent ∧ isGranted`, so a system-revoked permission shows OFF without a lying ON.
    @Shared(.appStorage("settingsRemindersEnabled")) public var remindersEnabled = false
    public var notificationAuthorization: NotificationAuthorizationStatus = .notDetermined

    /// The toggle's effective ON state — the user wants reminders AND the OS permits them.
    public var remindersEffectivelyOn: Bool { remindersEnabled && notificationAuthorization.isGranted }
    /// Show the "allow notifications in Settings" hint whenever notifications are **explicitly denied**
    /// (covers both a just-denied enable attempt — where `remindersEnabled` reverts to false — and a
    /// permission revoked while reminders were on). `.notDetermined` (never asked) shows no hint.
    public var showEnableInSettingsHint: Bool { notificationAuthorization == .denied }

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
    // Phase 10.3 reminders.
    case openNotificationSettingsTapped
    case remindersToggled(Bool)
    case authorizationResponse(NotificationAuthorizationStatus)
    case authorizationStatusLoaded(NotificationAuthorizationStatus)
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
  @Dependency(\.notificationClient) var notificationClient
  @Dependency(\.openURL) var openURL
  @Dependency(\.date) var date

  private enum CancelID { case load, reminders }

  /// The HealthKit presence-probe window. The status read only needs "did this category produce any
  /// sample recently", so it reads a bounded recent window rather than the whole history (review #2.2) —
  /// a category with no sample in this window shows as "not shared yet" (the plan's accepted
  /// emptiness-framing). 30 days comfortably covers an active user's core signals.
  private static let healthProbeWindow: TimeInterval = 30 * 24 * 60 * 60

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
          // intentionally NOT repeated here (it runs only on the first load — review #1.3). On a transient
          // read error PRESERVE the displayed value (only update on a successful read) rather than blanking
          // it to "Never synced" (review #2.3).
          // Also re-read the live notification authorization so a permission revoked while the app was
          // backgrounded flips the reminders toggle OFF (review/AC: the toggle never lies).
          return .run { [syncRepository, notificationClient] send in
            if let date = try? await syncRepository.lastSync() {
              await send(.lastSyncLoaded(date))
            }
            await send(.authorizationStatusLoaded(notificationClient.authorizationStatus()))
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
          let probeSince = date.now.addingTimeInterval(-Self.healthProbeWindow)
          return .run { [tokenClient, syncRepository, profileRepository, healthKitClient, notificationClient] send in
            async let token = try? await tokenClient.read()
            async let lastSyncDate = try? await syncRepository.lastSync()
            async let constants = loadConstants(profileRepository)
            async let health = loadHealthStatus(healthKitClient, since: probeSince)
            async let auth = notificationClient.authorizationStatus()
            await send(.connectionLoaded(token))
            await send(.lastSyncLoaded(lastSyncDate))
            await send(.constantsLoaded(constants))
            await send(.healthStatusLoaded(health))
            await send(.authorizationStatusLoaded(auth))
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
        // Clear the bearer token, then bubble the reset ONLY on a successful clear (fail-closed,
        // review #2.1): AppFeature's tokenReset handler routes to onboarding and assumes the session was
        // cleared, so a failed clear must NOT route — it would leave the stale token to resurrect on
        // restart. Reuses the existing reserved seam (DECISIONS #2) → the parent routes to .connect.
        return .run { [tokenClient] send in
          do {
            try await tokenClient.clear()
          } catch {
            return // clear failed → don't route; the old token is still present, the user can retry.
          }
          await send(.delegate(.tokenReset))
        }

      case .openHealthSettingsTapped:
        return .run { [openURL] _ in
          guard let url = URL(string: "x-apple-health://") else { return }
          await openURL(url)
        }

      case .openNotificationSettingsTapped:
        // "app-settings:" (UIApplication.openSettingsURLString) opens this app's iOS Settings page, where
        // notification permission can be re-enabled. Kept host-safe (no UIKit) via @Dependency(\.openURL).
        return .run { [openURL] _ in
          guard let url = URL(string: "app-settings:") else { return }
          await openURL(url)
        }

      case let .remindersToggled(isOn):
        if isOn {
          // Optimistic UI is avoided: request authorization first, then schedule/persist only if granted
          // (the response handler does the work). A thrown request is treated as not-granted. (A stale
          // in-flight onAppear auth read landing after this is a near-unreachable race — the async read
          // completes in ms, before any human tap — so it is accepted rather than cancelling the load,
          // review #2.1.)
          return .run { [notificationClient] send in
            let status = await (try? notificationClient.requestAuthorization()) ?? .denied
            await send(.authorizationResponse(status))
          }
          .cancellable(id: CancelID.reminders, cancelInFlight: true)
        } else {
          // Off needs no authorization — cancel both reminders and persist the intent.
          state.$remindersEnabled.withLock { $0 = false }
          return .run { [notificationClient] _ in
            await ReminderScheduler().disable(notificationClient)
          }
          .cancellable(id: CancelID.reminders, cancelInFlight: true)
        }

      case let .authorizationResponse(status):
        state.notificationAuthorization = status
        guard status.isGranted else {
          // Denied/not-determined (or a thrown request): keep the toggle OFF and surface the hint.
          state.$remindersEnabled.withLock { $0 = false }
          return .none
        }
        state.$remindersEnabled.withLock { $0 = true }
        return .run { [notificationClient] send in
          do {
            try await ReminderScheduler().enable(notificationClient)
          } catch {
            // A rare on-device schedule failure → revert intent like the denied path (no half-on state).
            await send(.remindersToggled(false))
          }
        }
        .cancellable(id: CancelID.reminders, cancelInFlight: true)

      case let .authorizationStatusLoaded(status):
        state.notificationAuthorization = status
        // Reconcile the schedule with the persisted intent + live permission on every appear/scene-active
        // (review #1.1/#1.3, #2.2) — BIDIRECTIONAL, so the schedule never disagrees with the toggle:
        //  • intent ON  ∧ granted  → (re-)schedule both (idempotent id-keyed replace) — heals an
        //    interrupted enable / a permission granted in iOS Settings.
        //  • otherwise (intent OFF, or not granted) → cancel both — heals an interrupted disable / a
        //    permission revoked while reminders were on, so a *repeating* reminder can't keep firing
        //    while the toggle shows OFF.
        return .run { [notificationClient, enabled = state.remindersEnabled, granted = status.isGranted] _ in
          if enabled, granted {
            try? await ReminderScheduler().enable(notificationClient)
          } else {
            await ReminderScheduler().disable(notificationClient)
          }
        }
        .cancellable(id: CancelID.reminders, cancelInFlight: true)

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
    return try await .success(repository.profile())
  } catch {
    return .failure(.failed)
  }
}

/// Probes HealthKit for the shared/missing status. When HK is unavailable, returns the all-missing
/// state **without** a delta read. Otherwise reduces a bounded `deltaSamples(since:)` probe per category
/// (emptiness ⇒ not shared — HK masks read grants, §3.3/6.3); `since` bounds the read to a recent window
/// (review #2.2) rather than the whole history. A free function so the `async let` in `onAppear` captures
/// no `self`.
private func loadHealthStatus(
  _ client: HealthKitClient,
  since: Date
) async -> SettingsFeature.HealthKitStatusState {
  guard client.isHealthDataAvailable() else {
    return HealthStatusInference.healthStatus(from: .empty, status: [:], available: false)
  }
  let set = await (try? client.deltaSamples(since)) ?? .empty
  return HealthStatusInference.healthStatus(from: set, status: client.authorizationStatus(), available: true)
}
