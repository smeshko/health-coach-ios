import CoachCore
import Foundation
import Testing

/// `CoachDeepLink` parser/vocabulary coverage (Phase 21.1 TASK-003): the canonical URLs round-trip,
/// foreign schemes/hosts are rejected, and matching is case-insensitive.
struct CoachDeepLinkTests {
  @Test func test_everyCase_roundTripsThroughItsCanonicalURL() {
    for link in CoachDeepLink.allCases {
      #expect(CoachDeepLink(url: link.url) == link)
    }
  }

  @Test func test_canonicalURLs_areTheFrozenStrings() {
    #expect(CoachDeepLink.today.url.absoluteString == "coachapp://today")
    #expect(CoachDeepLink.weekly.url.absoluteString == "coachapp://weekly")
    #expect(CoachDeepLink.checkIn.url.absoluteString == "coachapp://checkin")
  }

  @Test func test_foreignScheme_parsesNil() throws {
    let url = try #require(URL(string: "https://example.com"))
    #expect(CoachDeepLink(url: url) == nil)
  }

  @Test func test_unknownHost_parsesNil() throws {
    let url = try #require(URL(string: "coachapp://nope"))
    #expect(CoachDeepLink(url: url) == nil)
  }

  @Test func test_uppercaseVariants_parse() throws {
    let url = try #require(URL(string: "COACHAPP://CheckIn"))
    #expect(CoachDeepLink(url: url) == .checkIn)
  }
}
