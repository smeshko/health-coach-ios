import Dependencies
import Foundation
import Security
import TokenClient

extension TokenClient: DependencyKey {
  /// Keychain-backed live implementation — a generic-password item under a fixed service/account.
  public static let liveValue = TokenClient(
    read: { try KeychainTokenStore.read() },
    write: { try KeychainTokenStore.write($0) },
    clear: { try KeychainTokenStore.clear() }
  )
}

/// A thin wrapper over the `Security` generic-password Keychain item that backs the bearer token.
enum KeychainTokenStore {
  static let service = "com.coachapp.healthcoach"
  static let account = "bearer-token"

  enum KeychainError: Error, Sendable, Equatable {
    case unexpectedStatus(OSStatus)
  }

  private static var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }

  static func read() throws -> String? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    switch status {
    case errSecSuccess:
      guard let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
        return nil
      }
      return token
    case errSecItemNotFound:
      return nil
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }

  static func write(_ token: String) throws {
    let data = Data(token.utf8)
    let updateStatus = SecItemUpdate(
      baseQuery as CFDictionary,
      [kSecValueData as String: data] as CFDictionary
    )
    switch updateStatus {
    case errSecSuccess:
      return
    case errSecItemNotFound:
      var addQuery = baseQuery
      addQuery[kSecValueData as String] = data
      let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
      guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
    default:
      throw KeychainError.unexpectedStatus(updateStatus)
    }
  }

  static func clear() throws {
    let status = SecItemDelete(baseQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.unexpectedStatus(status)
    }
  }
}
