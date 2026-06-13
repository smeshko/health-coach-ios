import Testing
import TokenClient

/// Probe mirroring the old in-test `XCTSkip` gate: the live Keychain is usable iff clear+write
/// succeed. Runs in the `.enabled` trait before the live test and cleans up after itself, since it
/// no longer executes inside the test body.
private func keychainAvailable() async -> Bool {
  let client = TokenClient.liveValue
  do {
    try await client.clear()
    try await client.write("probe")
    try await client.clear()
    return true
  } catch {
    return false
  }
}

/// `.serialized`: the live test (and the trait probe) touch the real Keychain — a shared external
/// resource (D2: targeted serialization for genuinely shared state).
@Suite(.serialized) struct TokenClientTests {
  // The host `swift test` may run without a usable Keychain (sandbox / no entitlement); the
  // `.enabled` trait probes the Keychain and skips cleanly there so CI stays green.
  @Test(.enabled("Keychain unavailable in this environment") { await keychainAvailable() })
  func test_liveValue_roundTrips_keychain() async throws {
    let client = TokenClient.liveValue
    try await client.clear()
    try await client.write("live-token")
    let read = try await client.read()
    #expect(read == "live-token")
    try await client.clear()
    let afterClear = try await client.read()
    #expect(afterClear == nil)
  }

  /// Audit gap #9: every existing test clears first, so the `SecItemUpdate` (overwrite) branch is never
  /// hit — `write("a"); write("b"); read() == "b"` exercises the update-in-place path.
  @Test(.enabled("Keychain unavailable in this environment") { await keychainAvailable() })
  func test_liveValue_overwrite_updatesInPlace() async throws {
    let client = TokenClient.liveValue
    try await client.clear()
    try await client.write("a")
    try await client.write("b") // hits SecItemUpdate, not SecItemAdd
    let read = try await client.read()
    #expect(read == "b", "a second write overwrites the stored token")
    try await client.clear()
  }

  /// Audit gap #9: the empty-string-token contract. `write("")` stores empty data, so `read()` returns
  /// `""` (NOT nil) — which would yield a bare `Authorization: Bearer ` header. Pin the contract.
  @Test(.enabled("Keychain unavailable in this environment") { await keychainAvailable() })
  func test_liveValue_emptyString_roundTripsAsEmptyNotNil() async throws {
    let client = TokenClient.liveValue
    try await client.clear()
    try await client.write("")
    let read = try await client.read()
    #expect(read == "", "an empty-string token reads back as \"\", distinct from a missing (nil) token")
    try await client.clear()
  }
}
