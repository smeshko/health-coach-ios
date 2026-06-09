import APIClient
import Testing
import WireModels

struct APIErrorTests {
  @Test func test_apiError_fromErrorResponse_mapsCodeMessageDetailStatus() {
    let envelope = ErrorResponse(
      error: WireError(code: .known(.validationError), message: "bad request", detail: "date invalid")
    )
    let error = APIError(envelope: envelope, status: 422)
    #expect(
      error ==
        .envelope(code: .known(.validationError), message: "bad request", detail: "date invalid", status: 422)
    )
  }

  @Test func test_apiError_fromErrorResponse_preservesUnknownCode() {
    let envelope = ErrorResponse(error: WireError(code: .unknown("teapot"), message: "?", detail: nil))
    let error = APIError(envelope: envelope, status: 418)
    #expect(error == .envelope(code: .unknown("teapot"), message: "?", detail: nil, status: 418))
  }

  @Test func test_apiError_equatable() {
    #expect(APIError.unauthorized == .unauthorized)
    #expect(APIError.unauthorized != .unexpectedStatus(500))
    #expect(APIError.unexpectedStatus(502) == .unexpectedStatus(502))
    #expect(APIError.decoding("a") != .decoding("b"))
  }
}
