import APIClientLive
import Foundation
import Testing

/// CR-1 pin: the localhost / cleartext-http fallback is expressible ONLY on the
/// DEBUG+simulator path (`allowInsecureFallback: true`). Off that path the resolver must
/// yield https, non-loopback URLs or nothing — never a URL a release build shouldn't target.
struct APIBaseURLTests {
  // MARK: Valid configured values

  @Test func test_validHTTPS_resolves_regardlessOfFallbackFlag() {
    for allow in [true, false] {
      let url = APIBaseURL.resolve(
        configuredValue: "https://coach.example.com", allowInsecureFallback: allow
      )
      #expect(url == URL(string: "https://coach.example.com"), "allow=\(allow)")
    }
  }

  @Test func test_validHTTPS_withPortAndPath_resolves_offFallback() {
    let url = APIBaseURL.resolve(
      configuredValue: "https://coach.example.com:8443/api", allowInsecureFallback: false
    )
    #expect(url == URL(string: "https://coach.example.com:8443/api"))
  }

  @Test func test_surroundingWhitespace_isTrimmed() {
    let url = APIBaseURL.resolve(
      configuredValue: "  https://coach.example.com\n", allowInsecureFallback: false
    )
    #expect(url == URL(string: "https://coach.example.com"))
  }

  @Test func test_cleartextHTTP_resolvesOnlyWithInsecureFallback() {
    let raw = "http://192.168.0.10:8000"
    #expect(
      APIBaseURL.resolve(configuredValue: raw, allowInsecureFallback: true)
        == URL(string: raw)
    )
    #expect(APIBaseURL.resolve(configuredValue: raw, allowInsecureFallback: false) == nil)
  }

  // MARK: Unconfigured → localhost fallback iff allowed

  private static let unconfiguredValues: [String?] = [nil, "", "   \n", "$(API_BASE_URL)"]

  @Test(arguments: unconfiguredValues)
  func test_unconfigured_fallsBackToLocalhost_whenInsecureFallbackAllowed(raw: String?) {
    let url = APIBaseURL.resolve(configuredValue: raw, allowInsecureFallback: true)
    #expect(url == URL(string: "http://localhost:8000"))
  }

  @Test(arguments: unconfiguredValues)
  func test_unconfigured_isNil_whenInsecureFallbackOff(raw: String?) {
    #expect(APIBaseURL.resolve(configuredValue: raw, allowInsecureFallback: false) == nil)
  }

  // MARK: Garbage → nil (misconfigured, never substituted with localhost)

  private static let garbageValues: [String] = [
    "not a url",
    "ftp://x",
    "coach.example.com", // scheme-less
    "https://", // no host
  ]

  @Test(arguments: garbageValues)
  func test_garbage_isNil_evenWithInsecureFallbackAllowed(raw: String) {
    #expect(APIBaseURL.resolve(configuredValue: raw, allowInsecureFallback: true) == nil)
  }

  @Test(arguments: garbageValues)
  func test_garbage_isNil_offFallback(raw: String) {
    #expect(APIBaseURL.resolve(configuredValue: raw, allowInsecureFallback: false) == nil)
  }

  // MARK: The CR-1 + transport-boundary pin: no localhost/loopback and no http off-fallback

  private static let insecureOrLoopbackValues: [String] = [
    // Cleartext http — any host, any casing.
    "http://localhost:8000",
    "http://coach.example.com",
    "HTTP://coach.example.com",
    // Loopback over https — classified, not string-compared.
    "https://localhost",
    "https://localhost:8000",
    "https://LOCALHOST",
    "https://localhost.", // trailing-dot FQDN form
    "https://127.0.0.1",
    "https://127.0.0.1:8000",
    "https://127.0.0.2", // anywhere in 127/8, not just .0.0.1
    "https://[::1]", // IPv6 loopback
    "https://[::1]:8000",
    "https://[::ffff:127.0.0.1]", // IPv4-mapped loopback
  ]

  @Test(arguments: insecureOrLoopbackValues)
  func test_loopbackOrCleartext_neverResolves_whenInsecureFallbackOff(raw: String) {
    #expect(APIBaseURL.resolve(configuredValue: raw, allowInsecureFallback: false) == nil)
  }
}
