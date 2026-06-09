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
    let request = try urlRequest(for: Routes.health, baseURL: prefixed, bearer: nil)
    #expect(request.url?.absoluteString == "https://api.example.com/v1/health")
  }

  @Test func test_health_isGet_noAuthHeader() throws {
    let request = try urlRequest(for: Routes.health, baseURL: baseURL, bearer: bearer)
    #expect(request.url?.absoluteString == "http://localhost:8000/health")
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil, "/health must not be authenticated")
    #expect(request.httpBody == nil)
  }

  @Test func test_probe_isGet_withAuthHeader() throws {
    let request = try urlRequest(for: Routes.probe, baseURL: baseURL, bearer: bearer)
    #expect(request.url?.absoluteString == "http://localhost:8000/probe")
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
  }

  @Test func test_profile_isGet_withAuthHeader() throws {
    let request = try urlRequest(for: Routes.profile, baseURL: baseURL, bearer: bearer)
    #expect(request.url?.absoluteString == "http://localhost:8000/profile")
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
  }

  @Test func test_sync_postsEncodedBody_withAuthAndContentType() throws {
    let syncRequest = SyncRequest(checkin: DailyCheckin(
      date: calendarDay(2026, 6, 6),
      giSymptoms: false, kneePain: 1, illness: false
    ))
    let request = try urlRequest(for: Routes.sync(syncRequest), baseURL: baseURL, bearer: bearer)
    #expect(request.url?.absoluteString == "http://localhost:8000/sync")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    #expect(try decodeBody(SyncRequest.self, request) == syncRequest)
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
}
