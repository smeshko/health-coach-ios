import Dependencies
import Foundation

/// The bearer-token store dependency — `read`/`write`/`clear` (ARCHITECTURE §6/D12). The network
/// client asks this for the `Authorization` header per request. A `Sendable` struct of `@Sendable`
/// closures so the live (Keychain) and test (in-memory) implementations swap cleanly.
public struct TokenClient: Sendable {
  public var read: @Sendable () async throws -> String?
  public var write: @Sendable (String) async throws -> Void
  public var clear: @Sendable () async throws -> Void

  public init(
    read: @escaping @Sendable () async throws -> String?,
    write: @escaping @Sendable (String) async throws -> Void,
    clear: @escaping @Sendable () async throws -> Void
  ) {
    self.read = read
    self.write = write
    self.clear = clear
  }
}

public extension DependencyValues {
  var tokenClient: TokenClient {
    get { self[TokenClient.self] }
    set { self[TokenClient.self] = newValue }
  }
}
