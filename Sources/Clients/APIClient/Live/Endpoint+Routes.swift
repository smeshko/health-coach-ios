import Foundation
import WireModels

/// The five route factories (internal). Brief routes declare `.transientOnly` (502/504-retryable);
/// the others `.never`. POST routes build their JSON body unconditionally via `WireCoder.encoder`
/// (the openapi `requestBody` is `required: true`).
enum Routes {
  static var probe: Endpoint<[String: Bool]> {
    Endpoint(method: .get, path: "/probe", retry: .never)
  }

  static func sync(_ body: SyncRequest) -> Endpoint<SyncResponse> {
    Endpoint(path: "/sync", body: { try WireCoder.encoder.encode(body) }, retry: .never)
  }

  static func dailyBrief(date: Date?, refresh: Bool) -> Endpoint<DailyBrief> {
    let request = DailyBriefRequest(date: date.map(WireCalendarDate.init))
    return Endpoint(
      path: "/brief/daily",
      query: refreshQuery(refresh),
      body: { try WireCoder.encoder.encode(request) },
      retry: .transientOnly
    )
  }

  static func weeklyBrief(isoWeek: String?, refresh: Bool) -> Endpoint<WeeklyPlan> {
    let request = WeeklyBriefRequest(isoWeek: isoWeek)
    return Endpoint(
      path: "/brief/weekly",
      query: refreshQuery(refresh),
      body: { try WireCoder.encoder.encode(request) },
      retry: .transientOnly
    )
  }

  static var profile: Endpoint<ProfileResponse> {
    Endpoint(method: .get, path: "/profile", retry: .never)
  }

  private static func refreshQuery(_ refresh: Bool) -> [URLQueryItem] {
    refresh ? [URLQueryItem(name: "refresh", value: "true")] : []
  }
}
