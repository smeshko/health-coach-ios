import APIClient
import APIClientLive
import Clocks
import Dependencies
import Foundation
import LogClient
import TokenClient
import WireModels
import XCTest

final class TransportLoggingTests: XCTestCase {
  private let baseURL = URL(string: "http://localhost:8000")!
  private let token = "SECRET-BEARER-XYZ"

  private func makeClient() -> APIClient {
    let token = token
    let tokenClient = TokenClient(read: { token }, write: { _ in }, clear: {})
    return APIClient.live(
      baseURL: baseURL, session: URLProtocolStub.makeSession(), tokenClient: tokenClient
    )
  }

  private let dailyBriefJSON = Data("""
  {
    "data": {
      "date": "2026-06-06",
      "readiness": { "score": 84, "band": "green", "penalties": [] },
      "safetyGate": { "triggered": false, "reasons": [] },
      "session": {
        "card": "easy_run", "intensity": "easy",
        "durationMinLow": 40, "durationMinHigh": 55, "flags": []
      },
      "alternatives": [],
      "skipOk": true,
      "macroFocus": {
        "dayType": "moderate", "caloriesKcal": 2600, "proteinG": 170, "carbsG": 300,
        "fatGLow": 60, "fatGHigh": 80, "hydrationLLow": 2.5, "hydrationLHigh": 3.5
      },
      "generatedAt": "2026-06-06T07:30:00+03:00",
      "cached": false
    },
    "narrative": []
  }
  """.utf8)

  /// Every text fragment (message + metadata values) of every captured entry — for redaction checks.
  private func allText(_ recorder: LogRecorder) -> [String] {
    recorder.entries.flatMap { [$0.message] + Array($0.metadata.values) }
  }

  func test_logsRequestAndResponse_redactsBearer_bodyIntact() async throws {
    URLProtocolStub.box.setResponses([.init(status: 200, data: dailyBriefJSON)])
    let recorder = LogRecorder()
    let client = makeClient()

    _ = try await withDependencies {
      $0.log = .recording(into: recorder)
      $0.continuousClock = ImmediateClock()
    } operation: {
      // A POST route requiring auth: bearer rides the Authorization header, body is JSON.
      try await client.dailyBrief(Date(timeIntervalSince1970: 1_780_000_000), false)
    }

    // Everything is logged under `.http`.
    XCTAssertFalse(recorder.entries.isEmpty)
    XCTAssertTrue(recorder.entries.allSatisfy { $0.category == .http })

    // A request entry exists, with the Authorization header masked.
    let request = try XCTUnwrap(recorder.entries.first { $0.message.hasPrefix("request ") })
    let headers = try XCTUnwrap(request.metadata["headers"])
    XCTAssertTrue(headers.contains("Authorization=Bearer <redacted>"), "headers: \(headers)")

    // The bearer never leaks into any logged line.
    XCTAssertFalse(allText(recorder).contains { $0.contains(token) }, "raw bearer leaked into a log line")

    // The request body is logged in full (JSON object, not truncated/empty).
    let body = try XCTUnwrap(request.metadata["body"])
    XCTAssertNotEqual(body, "<empty>")
    XCTAssertTrue(body.contains("{"), "body not logged in full: \(body)")

    // A response entry carries the status.
    let response = try XCTUnwrap(recorder.entries.first { $0.message.hasPrefix("response ") })
    XCTAssertEqual(response.metadata["status"], "200")
  }

  func test_logs401_underHTTP() async throws {
    URLProtocolStub.box.setResponses([.init(status: 401, data: Data())])
    let recorder = LogRecorder()
    let client = makeClient()

    await withDependencies {
      $0.log = .recording(into: recorder)
    } operation: {
      _ = try? await client.profile()
    }

    let unauthorized = recorder.entries.first { $0.message.contains("unauthorized") }
    XCTAssertNotNil(unauthorized)
    XCTAssertEqual(unauthorized?.category, .http)
    XCTAssertFalse(allText(recorder).contains { $0.contains(token) })
  }

  func test_logsError_withMappedAPIError() async throws {
    URLProtocolStub.box.setResponses([
      .init(status: 500, data: Data(#"{"error":{"code":"internal_error","message":"m","detail":null}}"#.utf8)),
    ])
    let recorder = LogRecorder()
    let client = makeClient()

    await withDependencies {
      $0.log = .recording(into: recorder)
      $0.continuousClock = ImmediateClock()
    } operation: {
      _ = try? await client.profile()
    }

    let error = try XCTUnwrap(recorder.entries.first { $0.level == .error })
    XCTAssertEqual(error.category, .http)
    XCTAssertTrue(error.message.contains("error"), "expected a mapped error line, got: \(error.message)")
  }
}
