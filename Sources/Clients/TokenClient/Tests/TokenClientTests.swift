import Testing
import TokenClient
import TokenClientLive

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
  @Test func test_testValue_roundTrips_inMemory() async throws {
    let client = TokenClient.testValue
    let empty = try await client.read()
    #expect(empty == nil)

    try await client.write("t")
    let written = try await client.read()
    #expect(written == "t")

    try await client.clear()
    let cleared = try await client.read()
    #expect(cleared == nil)
  }

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
}
