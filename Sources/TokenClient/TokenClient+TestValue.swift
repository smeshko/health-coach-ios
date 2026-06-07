import Dependencies
import Foundation

extension TokenClient: TestDependencyKey {
  /// In-memory store (no Keychain) — round-trips writes within a dependency scope. The three
  /// closures share one actor-backed box.
  public static var testValue: TokenClient {
    let box = TokenBox()
    return TokenClient(
      read: { await box.token },
      write: { await box.set($0) },
      clear: { await box.set(nil) }
    )
  }

  /// A canned token for previews.
  public static var previewValue: TokenClient {
    let box = TokenBox(token: "preview-token")
    return TokenClient(
      read: { await box.token },
      write: { await box.set($0) },
      clear: { await box.set(nil) }
    )
  }
}

/// Strict-concurrency-safe in-memory token storage for `testValue`/`previewValue`.
private actor TokenBox {
  var token: String?

  init(token: String? = nil) {
    self.token = token
  }

  func set(_ value: String?) {
    token = value
  }
}
