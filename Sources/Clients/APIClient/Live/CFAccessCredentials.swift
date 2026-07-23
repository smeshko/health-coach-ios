import Foundation

/// Resolves the Cloudflare Access service-token pair from the `CFAccessClientId` /
/// `CFAccessClientSecret` Info.plist values (backed by the `CF_ACCESS_CLIENT_ID` /
/// `CF_ACCESS_CLIENT_SECRET` build settings, shipped empty in the repo — the owner fills the
/// git-ignored `Config/Secrets.xcconfig`).
///
/// The pair is all-or-nothing: a missing, empty, or unsubstituted (`$(…)`) value on either side
/// resolves the whole thing to `nil`, so requests never carry a half-configured credential. When
/// unconfigured the app still works against an origin that has no Access gate (localhost dev,
/// LAN) — Cloudflare simply never sees the headers.
public enum CFAccessCredentials {
  /// Exact header names Cloudflare Access authenticates service tokens by.
  public static let clientIdHeader = "CF-Access-Client-Id"
  public static let clientSecretHeader = "CF-Access-Client-Secret"

  /// Pure core, unit-testable. Returns the two `CF-Access-*` headers, or `nil` unless both
  /// values are present, non-empty after trimming, and actually substituted.
  public static func resolve(clientId: String?, clientSecret: String?) -> [String: String]? {
    guard let id = sanitized(clientId), let secret = sanitized(clientSecret) else { return nil }
    return [clientIdHeader: id, clientSecretHeader: secret]
  }

  /// Convenience for the composition root: reads both Info.plist keys.
  public static func resolve(bundle: Bundle) -> [String: String]? {
    resolve(
      clientId: bundle.object(forInfoDictionaryKey: "CFAccessClientId") as? String,
      clientSecret: bundle.object(forInfoDictionaryKey: "CFAccessClientSecret") as? String
    )
  }

  /// Trimmed value, with empty and unsubstituted `$(VAR)` placeholders normalised to `nil`.
  private static func sanitized(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty, !trimmed.hasPrefix("$(")
    else { return nil }
    return trimmed
  }
}
