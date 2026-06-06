.PHONY: format lint test build

# Format all Swift sources in place (idempotent).
format:
	swiftformat .

# Lint Sources/ + Tests/; --strict makes any warning a failure.
lint:
	swiftlint lint --strict

# Host logic tests (CoachCoreTests + AppFeatureTests) on the macOS host.
test:
	swift test

# Compile the package for the macOS host.
build:
	swift build
