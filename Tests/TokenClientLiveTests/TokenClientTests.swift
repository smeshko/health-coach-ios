import TokenClient
import TokenClientLive
import XCTest

final class TokenClientTests: XCTestCase {
  func test_testValue_roundTrips_inMemory() async throws {
    let client = TokenClient.testValue
    let empty = try await client.read()
    XCTAssertNil(empty)

    try await client.write("t")
    let written = try await client.read()
    XCTAssertEqual(written, "t")

    try await client.clear()
    let cleared = try await client.read()
    XCTAssertNil(cleared)
  }

  func test_liveValue_roundTrips_keychain() async throws {
    let client = TokenClient.liveValue
    // The host `swift test` may run without a usable Keychain (sandbox / no entitlement); skip
    // cleanly there so CI stays green.
    do {
      try await client.clear()
      try await client.write("live-token")
    } catch {
      throw XCTSkip("Keychain unavailable in this environment: \(error)")
    }
    let read = try await client.read()
    XCTAssertEqual(read, "live-token")
    try await client.clear()
    let afterClear = try await client.read()
    XCTAssertNil(afterClear)
  }
}
