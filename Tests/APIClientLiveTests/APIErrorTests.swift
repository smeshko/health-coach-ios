import APIClient
import WireModels
import XCTest

final class APIErrorTests: XCTestCase {
  func test_apiError_fromErrorResponse_mapsCodeMessageDetailStatus() {
    let envelope = ErrorResponse(
      error: WireError(code: .known(.validationError), message: "bad request", detail: "date invalid")
    )
    let error = APIError(envelope: envelope, status: 422)
    XCTAssertEqual(
      error,
      .envelope(code: .known(.validationError), message: "bad request", detail: "date invalid", status: 422)
    )
  }

  func test_apiError_fromErrorResponse_preservesUnknownCode() {
    let envelope = ErrorResponse(error: WireError(code: .unknown("teapot"), message: "?", detail: nil))
    let error = APIError(envelope: envelope, status: 418)
    XCTAssertEqual(error, .envelope(code: .unknown("teapot"), message: "?", detail: nil, status: 418))
  }

  func test_apiError_equatable() {
    XCTAssertEqual(APIError.unauthorized, .unauthorized)
    XCTAssertNotEqual(APIError.unauthorized, .unexpectedStatus(500))
    XCTAssertEqual(APIError.unexpectedStatus(502), .unexpectedStatus(502))
    XCTAssertNotEqual(APIError.decoding("a"), .decoding("b"))
  }
}
