import APIClient
import APIClientLive
import Clocks
import Dependencies
import Foundation
import LogClient
import Testing
import TokenClient
import WireModels

extension URLProtocolStubSerialized {
  struct TransportLoggingTests {
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

    @Test func test_logsRequestAndResponse_redactsBearer_bodyIntact() async throws {
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
      #expect(!recorder.entries.isEmpty)
      #expect(recorder.entries.allSatisfy { $0.category == .http })

      // A request entry exists, with the Authorization header masked.
      let request = try #require(recorder.entries.first { $0.message.hasPrefix("request ") })
      let headers = try #require(request.metadata["headers"])
      #expect(headers.contains("Authorization=Bearer <redacted>"), "headers: \(headers)")

      // The bearer never leaks into any logged line.
      #expect(!allText(recorder).contains(where: { $0.contains(token) }), "raw bearer leaked into a log line")

      // The request body is logged in full (JSON object, not truncated/empty).
      let body = try #require(request.metadata["body"])
      #expect(body != "<empty>")
      #expect(body.contains("{"), "body not logged in full: \(body)")

      // A response entry carries the status.
      let response = try #require(recorder.entries.first { $0.message.hasPrefix("response ") })
      #expect(response.metadata["status"] == "200")
    }

    @Test func test_logs401_underHTTP() async throws {
      URLProtocolStub.box.setResponses([.init(status: 401, data: Data())])
      let recorder = LogRecorder()
      let client = makeClient()

      await withDependencies {
        $0.log = .recording(into: recorder)
      } operation: {
        _ = try? await client.profile()
      }

      let unauthorized = recorder.entries.first { $0.message.contains("unauthorized") }
      #expect(unauthorized != nil)
      #expect(unauthorized?.category == .http)
      #expect(!allText(recorder).contains(where: { $0.contains(token) }))
    }

    @Test func test_logsError_withMappedAPIError() async throws {
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

      let error = try #require(recorder.entries.first { $0.level == .error })
      #expect(error.category == .http)
      // The line embeds the route and the actual mapped `APIError` description — assert the real content
      // (the bare `contains("error")` was trivially satisfied by the `error <path>:` prefix).
      #expect(error.message.contains("/profile"), "error line should name the route: \(error.message)")
      #expect(
        error.message.contains("envelope") && error.message.contains("internalError"),
        "error line should carry the mapped APIError, got: \(error.message)"
      )
    }
  }
}
