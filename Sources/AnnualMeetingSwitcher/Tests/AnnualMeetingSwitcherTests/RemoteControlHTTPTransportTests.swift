import XCTest
@testable import LiveSwitcher

final class RemoteControlHTTPTransportTests: XCTestCase {
    func testHTTPRequestAccumulatorWaitsForCompleteContentLengthBody() {
        let body = #"{"id":"11111111-1111-1111-1111-111111111111","kind":"takeNext"}"#
        let headers = """
        POST /api/command HTTP/1.1\r
        Authorization: Bearer token-1\r
        X-Remote-Client-ID: phone-a-1\r
        Content-Length: \(body.utf8.count)\r
        \r

        """
        var accumulator = RemoteControlHTTPRequestAccumulator()

        XCTAssertEqual(accumulator.append(Data(headers.utf8)), .waiting)

        let complete = accumulator.append(Data(body.utf8))

        XCTAssertEqual(complete, .complete(Data((headers + body).utf8)))
        guard case .complete(let requestData) = complete else {
            return XCTFail("Expected complete request data")
        }
        let request = RemoteControlHTTPParser.parse(String(decoding: requestData, as: UTF8.self))
        XCTAssertEqual(request?.body, Data(body.utf8))
    }

    func testHTTPRequestAccumulatorRejectsOversizedRequestsWithoutReturningPartialData() {
        let body = String(repeating: "a", count: 32)
        let headers = """
        POST /api/command HTTP/1.1\r
        Authorization: Bearer token-1\r
        Content-Length: \(body.utf8.count)\r
        \r

        """
        var accumulator = RemoteControlHTTPRequestAccumulator(maxByteCount: headers.utf8.count + 8)

        XCTAssertEqual(accumulator.append(Data(headers.utf8)), .oversized)
    }

    func testHTTPRequestAccumulatorRejectsMalformedContentLength() {
        let raw = """
        POST /api/command HTTP/1.1\r
        Authorization: Bearer token-1\r
        Content-Length: nope\r
        \r
        {"kind":"takeNext"}
        """
        var accumulator = RemoteControlHTTPRequestAccumulator()

        XCTAssertEqual(accumulator.append(Data(raw.utf8)), .malformed)
    }

    func testWireCodecSerializesPayloadTooLargeWithoutEchoingRequestData() {
        let response = RemoteControlHTTPResponse.json(
            statusCode: 413,
            [("error", "requestTooLarge")]
        )

        let raw = String(
            decoding: RemoteControlHTTPWireCodec.serialize(response),
            as: UTF8.self
        )

        XCTAssertTrue(raw.contains("HTTP/1.1 413 Payload Too Large"))
        XCTAssertTrue(raw.contains(#""error":"requestTooLarge""#))
        XCTAssertFalse(raw.contains("token-1"))
        XCTAssertFalse(raw.contains("Authorization"))
    }

    func testResponseFactoriesIncludeNoStoreAndBrowserHardeningHeaders() {
        let responses = [
            RemoteControlHTTPResponse.text(
                statusCode: 200,
                contentType: "text/html; charset=utf-8",
                "ok"
            ),
            RemoteControlHTTPResponse.json(
                statusCode: 200,
                [("status", "ok")]
            ),
            RemoteControlHTTPResponse.jsonData(
                statusCode: 200,
                Data(#"{"status":"ok"}"#.utf8)
            )
        ]

        for response in responses {
            XCTAssertEqual(response.header("cache-control"), "no-store")
            XCTAssertEqual(response.header("pragma"), "no-cache")
            XCTAssertEqual(response.header("x-content-type-options"), "nosniff")
            XCTAssertEqual(
                response.header("content-security-policy"),
                "default-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'"
            )
        }
    }

    func testExplicitHeadersOverrideDefaultsCaseInsensitively() {
        let response = RemoteControlHTTPResponse(
            statusCode: 200,
            headers: ["cache-control": "max-age=60"],
            body: Data()
        )

        XCTAssertEqual(response.header("cache-control"), "max-age=60")
        XCTAssertEqual(response.header("pragma"), "no-cache")
    }

    func testWireCodecSerializesBrowserHardeningHeaders() {
        let response = RemoteControlHTTPResponse.text(
            statusCode: 200,
            contentType: "text/plain; charset=utf-8",
            "ok"
        )

        let raw = String(
            decoding: RemoteControlHTTPWireCodec.serialize(response),
            as: UTF8.self
        )

        XCTAssertTrue(raw.contains("cache-control: no-store"))
        XCTAssertTrue(raw.contains("pragma: no-cache"))
        XCTAssertTrue(raw.contains("x-content-type-options: nosniff"))
        XCTAssertTrue(raw.contains("content-security-policy: default-src 'self';"))
    }
}
