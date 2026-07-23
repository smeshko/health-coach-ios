import DomainModels
import Foundation
import Testing
import WireModels

@testable import APIClientLive

struct RequestBuildingTests {
  private let baseURL = URL(string: "http://localhost:8000")!
  private let bearer = "test-token"

  private func decodeBody<T: Decodable>(_ type: T.Type, _ request: URLRequest) throws -> T {
    let body = try #require(request.httpBody)
    return try WireCoder.decoder.decode(type, from: body)
  }

  /// A midnight-Europe/Sofia calendar date, so a `WireCalendarDate` round-trips to identity.
  private func calendarDay(_ year: Int, _ month: Int, _ day: Int) -> WireCalendarDate {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(identifier: "Europe/Sofia")!
    return WireCalendarDate(calendar.date(from: DateComponents(year: year, month: month, day: day))!)
  }

  @Test func test_baseURLWithPathPrefix_isPreserved() throws {
    let prefixed = URL(string: "https://api.example.com/v1")!
    let request = try urlRequest(for: Routes.probe, baseURL: prefixed, bearer: nil)
    #expect(request.url?.absoluteString == "https://api.example.com/v1/probe")
  }

  /// The two authed GET routes share one builder path — only the path literal differs. Folded into one
  /// test (audit MERGE: the former test_probe_isGet/test_profile_isGet); the routes carry different
  /// generic `Response` types, so they're exercised inline rather than via `@Test(arguments:)`.
  @Test func test_getRoutes_areGet_withAuthHeader() throws {
    let probe = try urlRequest(for: Routes.probe, baseURL: baseURL, bearer: bearer)
    #expect(probe.url?.absoluteString == "http://localhost:8000/probe")
    #expect(probe.httpMethod == "GET")
    #expect(probe.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")

    let profile = try urlRequest(for: Routes.profile, baseURL: baseURL, bearer: bearer)
    #expect(profile.url?.absoluteString == "http://localhost:8000/profile")
    #expect(profile.httpMethod == "GET")
    #expect(profile.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
  }

  @Test func test_sync_postsEncodedBody_withAuthAndContentType() throws {
    let syncRequest = SyncRequest(checkin: CheckIn(
      date: calendarDay(2026, 6, 6).value,
      giSymptoms: false, kneePain: 1, illness: false
    ))
    let request = try urlRequest(for: Routes.sync(syncRequest), baseURL: baseURL, bearer: bearer)
    #expect(request.url?.absoluteString == "http://localhost:8000/sync")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    // SyncRequest is encode-only; assert against the encoded JSON body.
    let body = try #require(request.httpBody)
    let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let checkin = try #require(object["checkin"] as? [String: Any])
    #expect(checkin["date"] as? String == "2026-06-06")
    #expect(checkin["kneePain"] as? Int == 1)
    #expect(checkin["giSymptoms"] as? Bool == false)
  }

  @Test func test_dailyBrief_refreshTrue_hasQuery_andBodyDecodesToDTO() throws {
    let date = calendarDay(2026, 6, 6)
    let request = try urlRequest(
      for: Routes.dailyBrief(date: date.value, refresh: true), baseURL: baseURL, bearer: bearer
    )
    #expect(request.url?.absoluteString == "http://localhost:8000/brief/daily?refresh=true")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(try decodeBody(DailyBriefRequest.self, request) == DailyBriefRequest(date: date))
  }

  @Test func test_dailyBrief_nilDate_refreshFalse_noQuery_bodyDecodesToNilDTO() throws {
    let request = try urlRequest(
      for: Routes.dailyBrief(date: nil, refresh: false), baseURL: baseURL, bearer: bearer
    )
    // No ?refresh when false; the openapi requestBody is required, so a present body is always sent.
    #expect(request.url?.absoluteString == "http://localhost:8000/brief/daily")
    #expect(request.httpBody != nil, "POST body is never omitted (requestBody required)")
    // Robust to whether 2.1 encodes nil as {} or {"date": null}: assert decode-equality, not bytes.
    #expect(try decodeBody(DailyBriefRequest.self, request) == DailyBriefRequest(date: nil))
  }

  @Test func test_weeklyBrief_withIsoWeek_andNilVariant() throws {
    let withWeek = try urlRequest(
      for: Routes.weeklyBrief(isoWeek: "2026-W24", refresh: true), baseURL: baseURL, bearer: bearer
    )
    #expect(withWeek.url?.absoluteString == "http://localhost:8000/brief/weekly?refresh=true")
    #expect(try decodeBody(WeeklyBriefRequest.self, withWeek) == WeeklyBriefRequest(isoWeek: "2026-W24"))

    let nilWeek = try urlRequest(
      for: Routes.weeklyBrief(isoWeek: nil, refresh: false), baseURL: baseURL, bearer: bearer
    )
    #expect(nilWeek.url?.absoluteString == "http://localhost:8000/brief/weekly")
    #expect(nilWeek.httpBody != nil)
    #expect(try decodeBody(WeeklyBriefRequest.self, nilWeek) == WeeklyBriefRequest(isoWeek: nil))
  }

  /// Cloudflare Access seam: extra headers ride every request alongside — never instead of —
  /// the bearer, and omitting them changes nothing (the default is empty).
  @Test func test_extraHeaders_attachedAlongsideAuth() throws {
    let extra = [
      "CF-Access-Client-Id": "coach-ios.access",
      "CF-Access-Client-Secret": "s3cret",
    ]
    let request = try urlRequest(for: Routes.probe, baseURL: baseURL, bearer: bearer, extraHeaders: extra)
    #expect(request.value(forHTTPHeaderField: "CF-Access-Client-Id") == "coach-ios.access")
    #expect(request.value(forHTTPHeaderField: "CF-Access-Client-Secret") == "s3cret")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")

    let without = try urlRequest(for: Routes.probe, baseURL: baseURL, bearer: bearer)
    #expect(without.value(forHTTPHeaderField: "CF-Access-Client-Id") == nil)
    #expect(without.value(forHTTPHeaderField: "CF-Access-Client-Secret") == nil)
  }

  /// An extra header colliding with a builder-owned header loses — `Authorization` stays the
  /// bearer's even if a misconfigured extra-header dict tries to claim it.
  @Test func test_extraHeaders_neverOverrideBuilderHeaders() throws {
    let request = try urlRequest(
      for: Routes.probe, baseURL: baseURL, bearer: bearer,
      extraHeaders: ["Authorization": "stolen"]
    )
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
  }
}
