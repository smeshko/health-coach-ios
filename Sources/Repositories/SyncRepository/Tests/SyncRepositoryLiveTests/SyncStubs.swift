import APIClient
import CheckInRepository
import DomainModels
import Foundation
import HealthKitClient
import StrengthTestRepository
import WireModels

/// Lock-guarded stub clients for the sync orchestration tests. Canned inputs are `let` (set once at
/// init) so the `@unchecked Sendable` promise holds; only the captured values are lock-guarded.
final class SyncStubs: @unchecked Sendable {
  private let lock = NSLock()
  private var _capturedRequest: SyncRequest?
  private var _capturedSince: Date?

  let apiResult: Result<SyncResponse, APIError>
  let samples: HealthSampleSet
  let checkin: DomainModels.CheckIn?
  let strengthTest: DomainModels.StrengthTest?

  init(
    apiResult: Result<SyncResponse, APIError>,
    samples: HealthSampleSet = HealthSampleSet(),
    checkin: DomainModels.CheckIn? = nil,
    strengthTest: DomainModels.StrengthTest? = nil
  ) {
    self.apiResult = apiResult
    self.samples = samples
    self.checkin = checkin
    self.strengthTest = strengthTest
  }

  var capturedRequest: SyncRequest? { lock.withLock { _capturedRequest } }
  var capturedSince: Date? { lock.withLock { _capturedSince } }

  func healthKit() -> HealthKitClient {
    HealthKitClient(
      isHealthDataAvailable: { true },
      requestAuthorization: {},
      authorizationStatus: { [:] },
      deltaSamples: { [self] since in
        lock.withLock { _capturedSince = since }
        return samples
      }
    )
  }

  func api() -> APIClient {
    APIClient(
      probe: { fatalError("unused") },
      sync: { [self] request in
        lock.withLock { _capturedRequest = request }
        return try apiResult.get()
      },
      dailyBrief: { _, _ in fatalError("unused") },
      weeklyBrief: { _, _ in fatalError("unused") },
      profile: { fatalError("unused") },
      sessionEvents: { AsyncStream { $0.finish() } }
    )
  }

  func checkInRepository() -> CheckInRepository {
    CheckInRepository(save: { _ in }, current: { [self] _ in checkin })
  }

  func strengthTestRepository() -> StrengthTestRepository {
    StrengthTestRepository(save: { _ in }, current: { [self] _ in strengthTest })
  }
}

/// A canned successful response with caller-supplied counts (defaults all-zero).
func syncResponse(
  recordsUpserted: Int = 0,
  recordsDuplicate: Int = 0,
  workoutsUpserted: Int = 0,
  activityDaysUpserted: Int = 0,
  checkinSaved: Bool = false,
  strengthTestSaved: Bool = false,
  serverTime: Date = Date(timeIntervalSince1970: 5000)
) -> SyncResponse {
  SyncResponse(
    recordsUpserted: recordsUpserted,
    recordsDuplicate: recordsDuplicate,
    workoutsUpserted: workoutsUpserted,
    activityDaysUpserted: activityDaysUpserted,
    checkinSaved: checkinSaved,
    strengthTestSaved: strengthTestSaved,
    serverTime: serverTime
  )
}
