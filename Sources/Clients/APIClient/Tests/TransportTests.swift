import APIClient
import APIClientLive
import Clocks
import Dependencies
import Foundation
import Testing
import TokenClient
import WireModels

extension URLProtocolStubSerialized {
  struct TransportTests {
    private let baseURL = URL(string: "http://localhost:8000")!

    private func makeClient(
      token: String? = "tok-123"
    ) -> APIClient {
      let tokenClient = TokenClient(read: { token }, write: { _ in }, clear: {})
      return APIClient.live(
        baseURL: baseURL, session: URLProtocolStub.makeSession(), tokenClient: tokenClient
      )
    }

    private func envelope(_ code: String) -> Data {
      Data(#"{"error":{"code":"\#(code)","message":"m","detail":null}}"#.utf8)
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

    private let profileJSON = Data("""
    {
      "athlete": { "age": 34, "sex": "male", "heightCm": 182, "goalWeightKg": 75.0 },
      "zones": {
        "z1": { "low": 100, "high": 130 }, "z2": { "low": 131, "high": 145 },
        "z3": { "low": 146, "high": 160 }, "z4": { "low": 161, "high": 175 },
        "z5": { "low": 176, "high": 190 }
      },
      "thresholds": {
        "maxHr": 190, "rhrBaseline": 48, "hrvBaselineMs": 65, "easyHrCap": 150,
        "cadenceCurrentSpm": 172, "cadenceTargetSpm": 180
      },
      "meta": { "constitutionVersion": "v3" }
    }
    """.utf8)

    // MARK: - Success

    @Test func test_success_decodesDTO_withWireCoder() async throws {
      URLProtocolStub.box.setResponses([.init(status: 200, data: Data(#"{"ok":true}"#.utf8))])
      let ok = try await makeClient().probe()
      #expect(ok)
    }

    // MARK: - Envelope decode

    private struct EnvelopeCase {
      var status: Int
      var raw: String
      var code: ErrorCode
    }

    @Test func test_envelope_decodesToAPIError_perCode() async throws {
      let cases = [
        EnvelopeCase(status: 422, raw: "validation_error", code: .validationError),
        EnvelopeCase(status: 404, raw: "not_found", code: .notFound),
        EnvelopeCase(status: 500, raw: "internal_error", code: .internalError),
        EnvelopeCase(status: 502, raw: "brief_generation_failed", code: .briefGenerationFailed),
        EnvelopeCase(status: 504, raw: "upstream_timeout", code: .upstreamTimeout),
      ]
      for testCase in cases {
        URLProtocolStub.box.setResponses([.init(status: testCase.status, data: envelope(testCase.raw))])
        // `profile` has `retry: .never`, so even 502/504 decode immediately (no retry path).
        await assertThrows(
          .envelope(code: .known(testCase.code), message: "m", detail: nil, status: testCase.status),
          from: { try await self.makeClient().profile() },
          message: testCase.raw
        )
      }
    }

    @Test func test_nonEnvelopeStatus_decodesUnexpectedStatus() async throws {
      URLProtocolStub.box.setResponses([.init(status: 500, data: Data("<html>oops</html>".utf8))])
      await assertThrows(.unexpectedStatus(500), from: { try await self.makeClient().profile() })
    }

    // MARK: - Retry (502/504, briefs only)

    @Test func test_502then200_brief_retriesAndSucceeds() async throws {
      URLProtocolStub.box.setResponses([
        .init(status: 502, data: envelope("brief_generation_failed")),
        .init(status: 200, data: dailyBriefJSON),
      ])
      let client = makeClient()
      let brief = try await withDependencies { $0.continuousClock = ImmediateClock() } operation: {
        try await client.dailyBrief(nil, false)
      }
      #expect(brief.data.readiness.band == .known(.green))
      #expect(URLProtocolStub.box.recordedRequests.count == 2)
    }

    @Test func test_504then200_brief_retriesAndSucceeds() async throws {
      URLProtocolStub.box.setResponses([
        .init(status: 504, data: envelope("upstream_timeout")),
        .init(status: 200, data: dailyBriefJSON),
      ])
      let client = makeClient()
      let brief = try await withDependencies { $0.continuousClock = ImmediateClock() } operation: {
        try await client.dailyBrief(nil, false)
      }
      #expect(brief.data.session.card == .known(.easyRun))
      #expect(URLProtocolStub.box.recordedRequests.count == 2)
    }

    @Test func test_502_repeatedly_stopsAtCap() async throws {
      URLProtocolStub.box.setResponses([.init(status: 502, data: envelope("brief_generation_failed"))])
      let client = makeClient()
      let error = await captureError { try await client.dailyBrief(nil, false) }
      #expect(
        error == .envelope(code: .known(.briefGenerationFailed), message: "m", detail: nil, status: 502)
      )
      // 1 initial request + 6 capped retries.
      #expect(URLProtocolStub.box.recordedRequests.count == 7)
    }

    @Test func test_502_nonBriefRoute_isNotRetried() async throws {
      URLProtocolStub.box.setResponses([.init(status: 502, data: envelope("brief_generation_failed"))])
      let client = makeClient()
      let error = await captureError { try await client.profile() }
      #expect(
        error == .envelope(code: .known(.briefGenerationFailed), message: "m", detail: nil, status: 502)
      )
      #expect(URLProtocolStub.box.recordedRequests.count == 1)
    }

    @Test func test_500_isNotRetried() async throws {
      URLProtocolStub.box.setResponses([.init(status: 500, data: envelope("internal_error"))])
      let client = makeClient()
      let error = await captureError { try await client.dailyBrief(nil, false) }
      #expect(
        error == .envelope(code: .known(.internalError), message: "m", detail: nil, status: 500)
      )
      #expect(URLProtocolStub.box.recordedRequests.count == 1)
    }

    // MARK: - probe (200 → true; 401 → throws via the session-stream path)

    @Test func test_probe_success_returnsTrue() async throws {
      URLProtocolStub.box.setResponses([.init(status: 200, data: Data(#"{"db":true}"#.utf8))])
      let result = try await makeClient().probe()
      #expect(result)
    }

    @Test func test_probe_401_throwsUnauthorized() async throws {
      URLProtocolStub.box.setResponses([.init(status: 401, data: Data())])
      let client = makeClient()
      await assertThrows(.unauthorized, from: { try await client.probe() })
    }

    // MARK: - 401 stream

    @Test func test_401_emitsUnauthorized_andThrows_withoutRetry() async throws {
      URLProtocolStub.box.setResponses([.init(status: 401, data: Data())])
      let client = makeClient()
      let events = client.sessionEvents()
      await assertThrows(.unauthorized, from: { try await client.profile() })

      var iterator = events.makeAsyncIterator()
      let event = await iterator.next()
      #expect(event == .unauthorized)
      // Exactly one request was made (no retry), which means exactly one `.unauthorized` was yielded.
      #expect(URLProtocolStub.box.recordedRequests.count == 1)
    }

    // MARK: - Bearer header

    @Test func test_bearerHeader_presentOnAuthRoutes() async throws {
      let client = makeClient(token: "tok-123")

      URLProtocolStub.box.setResponses([.init(status: 200, data: profileJSON)])
      _ = try await client.profile()
      #expect(
        URLProtocolStub.box.recordedRequests.last?.value(forHTTPHeaderField: "Authorization") ==
          "Bearer tok-123"
      )
    }

    // MARK: - Helper

    /// Run a throwing call under an `ImmediateClock` (so backoff sleeps return instantly) and return
    /// the thrown `APIError`. Returning the error out of the `withDependencies` operation keeps the
    /// assertion outside the `@Sendable` closure (no `self` capture / data-race).
    private func captureError(
      _ operation: @escaping @Sendable () async throws -> some Any
    ) async -> APIError? {
      await withDependencies {
        $0.continuousClock = ImmediateClock()
      } operation: {
        do {
          _ = try await operation()
          return nil
        } catch let error as APIError {
          return error
        } catch {
          return nil
        }
      }
    }

    private func assertThrows(
      _ expected: APIError,
      from operation: @escaping () async throws -> some Any,
      message: String = "",
      sourceLocation: SourceLocation = #_sourceLocation
    ) async {
      do {
        _ = try await operation()
        Issue.record("expected to throw \(expected) \(message)", sourceLocation: sourceLocation)
      } catch let error as APIError {
        #expect(error == expected, "\(message)", sourceLocation: sourceLocation)
      } catch {
        Issue.record("threw \(error), expected \(expected) \(message)", sourceLocation: sourceLocation)
      }
    }
  }
}
