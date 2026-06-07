import Foundation

enum URLRequestBuilderError: Error, Equatable {
  case invalidURL(path: String)
}

/// Compose a `URLRequest` from an `Endpoint`: base URL + path + query, method, JSON body +
/// `Content-Type` when present, and `Authorization: Bearer` **iff** the route requires auth (never
/// for `/health`).
func urlRequest(for endpoint: Endpoint<some Any>, baseURL: URL, bearer: String?) throws -> URLRequest {
  guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
    throw URLRequestBuilderError.invalidURL(path: endpoint.path)
  }
  components.path = endpoint.path
  components.queryItems = endpoint.query.isEmpty ? nil : endpoint.query
  guard let url = components.url else {
    throw URLRequestBuilderError.invalidURL(path: endpoint.path)
  }

  var request = URLRequest(url: url)
  request.httpMethod = endpoint.method.rawValue
  request.timeoutInterval = endpoint.timeout.timeInterval

  if let body = endpoint.body {
    request.httpBody = try body()
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  }

  if endpoint.requiresAuth, let bearer {
    request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
  }

  return request
}

extension Duration {
  /// The duration as `TimeInterval` seconds (for `URLRequest.timeoutInterval`).
  var timeInterval: TimeInterval {
    let (seconds, attoseconds) = components
    return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
  }
}
