import DomainModels
import Foundation
import HealthKitClient
import WireModels

// The HealthKit-payload → `WireModels.SyncRequest` mapping. It lives **here** (Phase 3.3 boundary
// decision): `HealthKitClient` ships plain payload structs and `WireDomainMapping` is response-shape
// only (2.2 Out-of-Scope). These are pure free functions — no I/O, trivially unit-testable, reused by
// the orchestration (TASK-003).

/// Map a HealthKit record payload to the wire `HealthRecord`. Reuses the `RecordType` tag the payload
/// already carries (wrapped in the forward-compatible `WireEnum`).
func wireHealthRecord(_ payload: HealthRecordPayload) -> HealthRecord {
  HealthRecord(
    uuid: payload.uuid,
    type: WireEnum(payload.type),
    start: payload.start,
    end: payload.end,
    value: payload.value,
    unit: payload.unit,
    category: payload.category,
    source: payload.source,
    metadata: payload.metadata.map(wireMetadata)
  )
}

/// Map a `[String: String]` metadata bag to the tolerant wire `JSONValue` object (string-valued).
private func wireMetadata(_ metadata: [String: String]) -> JSONValue {
  .object(metadata.mapValues(JSONValue.string))
}

func wireWorkoutStat(_ payload: WorkoutStatPayload) -> WorkoutStat {
  WorkoutStat(type: payload.type, value: payload.value, unit: payload.unit)
}

/// Map a HealthKit workout payload to the wire `Workout` (passing `zoneMinutes` through as the tolerant
/// `str→number` map openapi defines).
func wireWorkout(_ payload: WorkoutPayload) -> Workout {
  Workout(
    uuid: payload.uuid,
    type: payload.type,
    start: payload.start,
    end: payload.end,
    durationS: payload.durationS,
    distanceM: payload.distanceM,
    activeEnergyKcal: payload.activeEnergyKcal,
    effortScore: payload.effortScore,
    zoneMinutes: payload.zoneMinutes,
    statistics: payload.statistics.map(wireWorkoutStat)
  )
}

func wireActivitySummary(_ payload: ActivitySummaryPayload) -> ActivitySummary {
  ActivitySummary(
    date: WireCalendarDate(payload.date),
    activeEnergyKcal: payload.activeEnergyKcal,
    exerciseMinutes: payload.exerciseMinutes,
    standHours: payload.standHours,
    steps: payload.steps
  )
}

func wireDailyCheckin(_ checkIn: DomainModels.CheckIn) -> DailyCheckin {
  DailyCheckin(
    date: WireCalendarDate(checkIn.date),
    giSymptoms: checkIn.giSymptoms,
    kneePain: checkIn.kneePain,
    illness: checkIn.illness
  )
}

func wireStrengthTest(_ test: DomainModels.StrengthTest) -> WireModels.StrengthTest {
  WireModels.StrengthTest(
    date: WireCalendarDate(test.date),
    maxPushups: test.maxPushups,
    maxPullups: test.maxPullups
  )
}

/// Assemble the `SyncRequest` from a HealthKit delta set + the optional check-in / strength test. An
/// empty set + nil inputs yields a valid minimal request (empty arrays, nil singletons).
func buildSyncRequest(
  samples: HealthSampleSet,
  checkin: DomainModels.CheckIn?,
  strengthTest: DomainModels.StrengthTest?
) -> SyncRequest {
  SyncRequest(
    records: samples.records.map(wireHealthRecord),
    workouts: samples.workouts.map(wireWorkout),
    activitySummary: samples.activity.map(wireActivitySummary),
    checkin: checkin.map(wireDailyCheckin),
    strengthTest: strengthTest.map(wireStrengthTest)
  )
}
