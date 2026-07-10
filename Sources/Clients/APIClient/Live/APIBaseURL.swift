import Foundation

/// Resolves the API base URL from the configured `APIBaseURL` Info.plist value (backed by the
/// `API_BASE_URL` build setting).
///
/// CR-1 contract: the `http://localhost:8000` fallback — and cleartext http in general — is
/// expressible ONLY when `allowInsecureFallback` is true, which the bundle convenience grants
/// solely on DEBUG + simulator builds. Off that path the resolver yields https, non-loopback
/// URLs or `nil` (invalid ≡ unconfigured); a device/release build can never silently target
/// localhost or send the bearer token in the clear.
public enum APIBaseURL {
  /// Pure core, unit-testable. `nil`/empty/unsubstituted (`$(API_BASE_URL)`) input falls back
  /// to `http://localhost:8000` iff `allowInsecureFallback`; anything else must parse as a URL
  /// with a host and an https scheme (http accepted only with the fallback on). With the
  /// fallback off, loopback hosts are rejected even over https. Garbage returns `nil` — never
  /// a substituted localhost — so the caller surfaces the misconfiguration.
  public static func resolve(configuredValue: String?, allowInsecureFallback: Bool) -> URL? {
    let trimmed = configuredValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmed.isEmpty || trimmed == "$(API_BASE_URL)" {
      return allowInsecureFallback ? URL(string: "http://localhost:8000") : nil
    }

    guard
      let url = URL(string: trimmed),
      let scheme = url.scheme?.lowercased(),
      let host = url.host, !host.isEmpty
    else { return nil }

    if allowInsecureFallback {
      guard scheme == "https" || scheme == "http" else { return nil }
      return url
    }

    guard scheme == "https", !isLoopback(host: host) else { return nil }
    return url
  }

  /// Convenience for the composition root: reads the `"APIBaseURL"` Info.plist key and allows
  /// the insecure localhost fallback only on DEBUG + simulator builds.
  public static func resolve(bundle: Bundle) -> URL? {
    let configured = bundle.object(forInfoDictionaryKey: "APIBaseURL") as? String
    #if DEBUG && targetEnvironment(simulator)
      let allowInsecureFallback = true
    #else
      let allowInsecureFallback = false
    #endif
    return resolve(configuredValue: configured, allowInsecureFallback: allowInsecureFallback)
  }

  /// Classifies loopback hosts (rather than string-comparing a fixed list): `localhost`
  /// (case-insensitive, trailing FQDN dot stripped), any IPv4 literal in 127/8, IPv6 loopback
  /// `::1` (bracketed or not), and IPv4-mapped loopback (`::ffff:127.…`).
  private static func isLoopback(host: String) -> Bool {
    var normalized = host.lowercased()
    if normalized.hasSuffix(".") { normalized.removeLast() }
    if normalized.hasPrefix("["), normalized.hasSuffix("]") {
      normalized = String(normalized.dropFirst().dropLast())
    }
    if normalized == "localhost" { return true }
    if normalized.hasPrefix("127.") { return true } // IPv4 loopback block 127/8
    if normalized == "::1" { return true } // IPv6 loopback
    if normalized.hasPrefix("::ffff:127.") { return true } // IPv4-mapped loopback
    return false
  }
}
