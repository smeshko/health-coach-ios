import APIClient
import Dependencies
import DomainModels
import Foundation
import HealthKitClient
import LogClient
import SyncRepository
import WireModels

/// Chunked upload of a long read window (audit follow-up to Phase 18.2: the bounded read's
/// per-type row cap silently truncated the first-sync backfill to its newest ~10k samples per
/// type — a long window is now several bounded `[start, until)` reads + POSTs, never one
/// truncated read).

/// Chunk length for long read windows (backfill). One week keeps the highest-frequency type (heart
/// rate, ~6k samples/week with daily Watch wear) comfortably under the 10k per-type row cap while
/// the full May-23-floor backfill stays under ~10 POSTs; a window that still hits the cap is
/// visible via `logDeltaTruncation`.
let syncChunkLength: TimeInterval = 7 * 24 * 60 * 60

/// `[start, until)` windows of at most `chunk` covering the span; the FINAL window's `until` is
/// always `nil` (open-topped), so the everyday single-window delta is byte-identical to the
/// pre-chunking read and samples landing during the loop are picked up exactly as before. Windows
/// are contiguous (each `until` is the next `start`) and half-open, so no sample is double-read.
func syncWindows(
  from lower: Date, to upper: Date, chunk: TimeInterval = syncChunkLength
) -> [(start: Date, until: Date?)] {
  var windows: [(start: Date, until: Date?)] = []
  var cursor = lower
  while cursor.addingTimeInterval(chunk) < upper {
    let next = cursor.addingTimeInterval(chunk)
    windows.append((start: cursor, until: next))
    cursor = next
  }
  windows.append((start: cursor, until: nil))
  return windows
}

/// Read + POST each window in order and fold the responses. Per chunk: bounded HK read (per-type
/// row limit, 15s in-client timeout, 20s abandoning backstop — the pre-chunking contract, per
/// chunk) → POST. HK-unavailable/partial degrades to an empty set inside the client; an all-empty
/// NON-final chunk is skipped (pre-history windows POST nothing), the final chunk always POSTs
/// (zero-upsert success + today's check-in — the singletons ride the FINAL chunk only). Review
/// #1.1: cancellation can land in the same instant a read resumes success — re-checked before each
/// irreversible boundary.
func uploadChunks(
  _ windows: [(start: Date, until: Date?)],
  checkin: DomainModels.CheckIn?,
  strengthTest: DomainModels.StrengthTest?,
  clock: any Clock<Duration>
) async throws -> SyncResult {
  @Dependency(\.healthKitClient) var healthKit
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.log) var log

  var aggregate: SyncResult?
  for (index, window) in windows.enumerated() {
    let isLast = index == windows.count - 1
    let bounds = HealthReadBounds.window(window.start, until: window.until)
    let samples: HealthSampleSet
    do {
      samples = try await withSyncTimeout(healthReadTimeout, clock: clock) {
        try await healthKit.deltaSamples(bounds)
      }
    } catch HealthKitReadError.timedOut {
      throw SyncError.transient
    }
    try Task.checkCancellation()

    logDeltaTruncation(samples, bounds: bounds)
    if windows.count > 1 {
      log.notice(
        "backfill chunk \(index + 1)/\(windows.count): \(samples.records.count) records, "
          + "\(samples.workouts.count) workouts, \(samples.activity.count) activity days",
        category: .http
      )
    }

    let isEmptyChunk = samples.records.isEmpty && samples.workouts.isEmpty && samples.activity.isEmpty
    if isEmptyChunk, !isLast { continue }

    let request = buildSyncRequest(
      samples: samples,
      checkin: isLast ? checkin : nil,
      strengthTest: isLast ? strengthTest : nil
    )

    try Task.checkCancellation()
    let response: SyncResponse
    do {
      response = try await apiClient.sync(request)
    } catch let apiError as APIError {
      if isUnauthorized(apiError) { throw apiError }
      throw syncError(apiError)
    }
    aggregate = accumulate(aggregate, adding: syncResult(response))
  }

  // The final chunk always POSTs, so a completed loop always produced a result.
  guard let result = aggregate else { throw SyncError.transient }
  return result
}

/// Fold one chunk's mapped response into the running total: counts sum, the singleton flags OR
/// (they can only come from the final chunk anyway), `serverTime` takes the latest response.
private func accumulate(_ total: SyncResult?, adding next: SyncResult) -> SyncResult {
  guard var running = total else { return next }
  running.recordsUpserted += next.recordsUpserted
  running.recordsDuplicate += next.recordsDuplicate
  running.workoutsUpserted += next.workoutsUpserted
  running.activityDaysUpserted += next.activityDaysUpserted
  running.checkinSaved = running.checkinSaved || next.checkinSaved
  running.strengthTestSaved = running.strengthTestSaved || next.strengthTestSaved
  running.serverTime = next.serverTime
  return running
}
