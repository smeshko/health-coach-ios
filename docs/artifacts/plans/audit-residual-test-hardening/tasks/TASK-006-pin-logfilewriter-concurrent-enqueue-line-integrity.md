# TASK-006: Pin LogFileWriter concurrent-enqueue line integrity

Depends on: None
Suggested commit: `test(log): pin LogFileWriter concurrent-enqueue line integrity`

## Goal

Characterize the serial-actor guarantee `LogFileWriter`'s design hangs on: N parallel
writers each enqueuing M lines yield whole, non-interleaved lines (no partial/spliced
lines) and all N×M lines are present after a flush. Test-only.

## Files

- `Sources/Clients/LogClient/Tests/LogClientLiveTests/LogClientLiveTests.swift` — add the
  concurrency test, reusing the file-writer setup the rotation/readRecent tests already
  use (a `LogFileWriter` over a temp `Caches/Logs/`-style dir).

## Acceptance

- [ ] A test spawns N concurrent tasks (e.g. a `TaskGroup`), each enqueuing M uniquely
      identifiable lines, awaits a flush, then reads back: every line is intact (no line
      is a splice of two writers' content) and the multiset of lines equals the N×M
      enqueued (order across writers is unconstrained; per-writer order may be asserted
      if the API guarantees it).
- [ ] Deterministic completion (await the writer's drain, don't sleep).
- [ ] Host + sim suites green.

## Steps

### RED
- [ ] Write the concurrent-enqueue test: distinct line payloads per task (e.g.
      `"w\(writer)-l\(line)"`), flush, assert wholeness (each read line matches the
      `w\d+-l\d+` shape exactly) and completeness (count == N×M, set equality).

### GREEN
- [ ] n/a — pins the existing serial-actor behavior.

### REFACTOR
- [ ] Run the LogClient suite; confirm no temp-dir leakage; host + sim suites.

## Notes

`LogFileWriter` (`LogFileWriter.swift:14`) funnels `nonisolated enqueue(_:)` (`:95`)
through one `AsyncStream` consumed by a single actor loop (doc `:6`) "so lines never
interleave" — this test is the missing proof of that core claim. Flush/drain: use the
same readback mechanism the rotation tests use (`recentLines`/`readRecent`) after
ensuring the stream has drained; avoid wall-clock waits.
