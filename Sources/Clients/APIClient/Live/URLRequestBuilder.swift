import Foundation

enum URLRequestBuilderError: Error, Equatable {
  case invalidURL(path: String)
}

/// Compose a `URLRequest` from an `Endpoint`: base URL + path + query, method, JSON body +
/// `Content-Type` when present, and `Authorization: Bearer` whenever a bearer is present.
func urlRequest(for endpoint: Endpoint<some Any>, baseURL: URL, bearer: String?) throws -> URLRequest {
  guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
    throw URLRequestBuilderError.invalidURL(path: endpoint.path)
  }
  // Append onto any base path (e.g. a versioned `/v1`) rather than replacing it.
  components.path = (components.path as NSString).appendingPathComponent(endpoint.path)
  components.queryItems = endpoint.query.isEmpty ? nil : endpoint.query
  guard let url = components.url else {
    throw URLRequestBuilderError.invalidURL(path: endpoint.path)
  }

  var request = URLRequest(url: url)
  request.httpMethod = endpoint.method.rawValue

  if let body = endpoint.body {
    request.httpBody = try body()
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  }

  if let bearer {
    request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
  }

  return request
}
