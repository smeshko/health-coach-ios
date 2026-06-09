import Foundation
import Testing

/// Umbrella suite serializing every test that scripts the global `URLProtocolStub.box`.
/// `.serialized` applies recursively, so nesting both transport suites here prevents
/// cross-suite interleaving on the shared response queue (DECISIONS D2: genuinely shared
/// mutable state gets targeted serialization).
@Suite(.serialized) enum URLProtocolStubSerialized {}

/// A test-scoped `URLProtocol` that returns scripted responses and records issued requests. Installed
/// via a per-test `URLSessionConfiguration.protocolClasses` (DECISIONS Decision 1), so it never
/// touches `URLSession.shared`. Shared state is lock-guarded and reset per test via `setResponses`.
final class URLProtocolStub: URLProtocol {
  struct StubResponse {
    var status: Int
    var data: Data
    var headers: [String: String]

    init(status: Int, data: Data = Data(), headers: [String: String] = [:]) {
      self.status = status
      self.data = data
      self.headers = headers
    }
  }

  final class Box: @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [StubResponse] = []
    private var recorded: [URLRequest] = []

    func setResponses(_ responses: [StubResponse]) {
      lock.lock()
      defer { lock.unlock() }
      queue = responses
      recorded = []
    }

    /// Record the request and return the next scripted response; the last response repeats.
    func nextResponse(for request: URLRequest) -> StubResponse? {
      lock.lock()
      defer { lock.unlock() }
      recorded.append(request)
      guard !queue.isEmpty else { return nil }
      return queue.count == 1 ? queue[0] : queue.removeFirst()
    }

    var recordedRequests: [URLRequest] {
      lock.lock()
      defer { lock.unlock() }
      return recorded
    }
  }

  nonisolated(unsafe) static let box = Box()

  /// A `URLSession` wired to this stub.
  static func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    return URLSession(configuration: configuration)
  }

  // URLProtocol's overrides must be `class func` (not `static`), so the rule is a false positive.
  // swiftlint:disable static_over_final_class
  override class func canInit(with _: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  // swiftlint:enable static_over_final_class
  override func stopLoading() {}

  override func startLoading() {
    guard let url = request.url, let stub = Self.box.nextResponse(for: request) else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    let response = HTTPURLResponse(
      url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: stub.headers
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: stub.data)
    client?.urlProtocolDidFinishLoading(self)
  }
}
