import APIClient
import Testing
import WireModels

struct APIErrorTests {
  @Test func test_apiError_fromErrorResponse_mapsCodeMessageDetailStatus() {
    let envelope = ErrorResponse(
      error: WireError(code: .validationError, message: "bad request", detail: "date invalid")
    )
    let error = APIError(envelope: envelope, status: 422)
    #expect(
      error ==
        .envelope(code: .validationError, message: "bad request", detail: "date invalid", status: 422)
    )
  }

  // NOTE: the former `test_apiError_fromErrorResponse_preservesUnknownCode` is removed — `ErrorCode`
  // is now a strict wire-local enum (Phase 11.3): an out-of-set code throws a `DecodingError` at the
  // envelope-decode boundary and never reaches an `APIError`, so there is no `.unknown` to preserve.

  @Test func test_apiError_equatable() {
    #expect(APIError.unauthorized == .unauthorized)
    #expect(APIError.unauthorized != .unexpectedStatus(500))
    #expect(APIError.unexpectedStatus(502) == .unexpectedStatus(502))
    #expect(APIError.decoding("a") != .decoding("b"))
  }
}
