import Foundation
import Testing

@testable import APIClientLive

struct CFAccessCredentialsTests {
  @Test func test_bothValues_resolveToBothHeaders() {
    let headers = CFAccessCredentials.resolve(
      clientId: "coach-ios.access", clientSecret: "s3cret"
    )
    #expect(headers == [
      "CF-Access-Client-Id": "coach-ios.access",
      "CF-Access-Client-Secret": "s3cret",
    ])
  }

  @Test func test_valuesAreTrimmed() {
    let headers = CFAccessCredentials.resolve(
      clientId: " coach-ios.access\n", clientSecret: " s3cret "
    )
    #expect(headers?[CFAccessCredentials.clientIdHeader] == "coach-ios.access")
    #expect(headers?[CFAccessCredentials.clientSecretHeader] == "s3cret")
  }

  /// The pair is all-or-nothing: nil, empty, whitespace-only, or unsubstituted `$(VAR)` on
  /// EITHER side must disable both headers — a half-configured credential must never be sent.
  @Test(arguments: [nil, "", "  ", "$(CF_ACCESS_CLIENT_ID)"] as [String?])
  func test_badClientId_resolvesNil(bad: String?) {
    #expect(CFAccessCredentials.resolve(clientId: bad, clientSecret: "s3cret") == nil)
  }

  @Test(arguments: [nil, "", "  ", "$(CF_ACCESS_CLIENT_SECRET)"] as [String?])
  func test_badClientSecret_resolvesNil(bad: String?) {
    #expect(CFAccessCredentials.resolve(clientId: "coach-ios.access", clientSecret: bad) == nil)
  }

  /// App bundles in this test host carry no CFAccess keys, so the bundle convenience resolves
  /// nil rather than trapping or inventing values.
  @Test func test_unconfiguredBundle_resolvesNil() {
    #expect(CFAccessCredentials.resolve(bundle: .main) == nil)
  }
}
