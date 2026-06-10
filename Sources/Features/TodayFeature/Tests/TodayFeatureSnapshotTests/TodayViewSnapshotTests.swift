// Placeholder — the real TodayView snapshot tests (the loading / generating / sync-failed states, light
// + dark, on the iOS 26 simulator) land in TASK-005. The target is wired into the package graph here in
// TASK-001 so it exists end-to-end; its body is `#if canImport(UIKit)`-guarded (TASK-005) so it compiles
// to an empty module on the macOS host (the Swift/SPM host-build hazard) — keeping `swift test` green.
