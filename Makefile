.PHONY: format lint test build test-snapshots record-snapshots

# The single canonical simulator for iOS snapshot tests. Snapshot references are
# recorded on THIS exact device; running on any other simulator produces sub-pixel
# rendering diffs that fail at the default exact precision. Always go through the
# `test-snapshots` / `record-snapshots` targets so every run uses the same device.
SNAPSHOT_DEVICE = platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0
SNAPSHOT_WORKSPACE = .swiftpm/xcode/package.xcworkspace
SNAPSHOT_TARGETS = -only-testing:DesignSystemSnapshotTests -only-testing:AppFeatureSnapshotTests -only-testing:OnboardingFeatureSnapshotTests -only-testing:SettingsFeatureSnapshotTests -only-testing:TodayFeatureSnapshotTests -only-testing:WeeklyFeatureSnapshotTests

# Format all Swift sources in place (idempotent).
format:
	swiftformat .

# Lint the package source tree under Sources/ (Repositories/ Clients/ Features/ Models/ Core/
# DesignSystem/, tests co-located under each module); --strict makes any warning a failure.
lint:
	swiftlint lint --strict

# The full package unit-test suite (all non-snapshot targets) on the macOS host.
test:
	swift test

# Compile the package for the macOS host.
build:
	swift build

# iOS snapshot tests on the pinned canonical simulator (SwiftUI image snapshots are
# UIKit-only and cannot run under `swift test`). Always use this target so every run
# renders on the same device the references were recorded on.
test-snapshots:
	xcodebuild test \
	  -workspace $(SNAPSHOT_WORKSPACE) \
	  -scheme CoachKit-Package \
	  -destination '$(SNAPSHOT_DEVICE)' \
	  $(SNAPSHOT_TARGETS)

# Re-record snapshot references after an intentional view change, on the same pinned
# device. `TEST_RUNNER_*` forwards the var into the simulator test runner (a bare
# SNAPSHOT_TESTING_RECORD does not reach it). Record mode reports the recorded snapshots
# as failures (so CI never passes with record left on) → the leading `-` lets make ignore
# that expected non-zero exit. Always review the regenerated PNGs (`git diff`) before committing.
record-snapshots:
	-TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all xcodebuild test \
	  -workspace $(SNAPSHOT_WORKSPACE) \
	  -scheme CoachKit-Package \
	  -destination '$(SNAPSHOT_DEVICE)' \
	  $(SNAPSHOT_TARGETS)
