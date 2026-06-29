import XCTest
@testable import LiveSwitcher

final class RemoteControlRequestRouterTests: XCTestCase {
    func testParserReadsMethodPathHeadersAndBody() throws {
        let raw = """
        POST /api/command HTTP/1.1\r
        Host: 127.0.0.1\r
        Authorization: Bearer token-1\r
        Content-Length: 21\r
        \r
        {"kind":"takeNext"}
        """

        let request = try XCTUnwrap(RemoteControlHTTPParser.parse(raw))

        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, "/api/command")
        XCTAssertEqual(request.header("authorization"), "Bearer token-1")
        XCTAssertEqual(String(data: request.body, encoding: .utf8), #"{"kind":"takeNext"}"#)
    }

    func testParserKeepsFirstHeaderWhenNamesDifferOnlyByCase() throws {
        let raw = """
        GET /api/snapshot HTTP/1.1\r
        Authorization: Bearer token-1\r
        authorization: Bearer ignored\r
        \r

        """

        let request = try XCTUnwrap(RemoteControlHTTPParser.parse(raw))

        XCTAssertEqual(request.header("authorization"), "Bearer token-1")
    }

    func testHealthAndStaticAssetsDoNotRequireAuthorization() throws {
        let router = router()

        let health = router.route(.get("/health"))
        XCTAssertEqual(health.statusCode, 200)
        XCTAssertEqual(health.header("content-type"), "application/json")
        XCTAssertTrue(health.bodyText.contains("ok"))

        let page = router.route(.get("/"))
        XCTAssertEqual(page.statusCode, 200)
        XCTAssertEqual(page.header("content-type"), "text/html; charset=utf-8")
        XCTAssertTrue(page.bodyText.contains("LiveSwitcher Remote"))
        XCTAssertTrue(page.bodyText.contains(#"id="snapshot""#))
        XCTAssertFalse(page.bodyText.contains("data-command"))
        XCTAssertFalse(page.bodyText.localizedStandardContains("https://"))
        XCTAssertFalse(page.bodyText.localizedStandardContains("http://"))

        let css = router.route(.get("/remote.css"))
        XCTAssertEqual(css.statusCode, 200)
        XCTAssertEqual(css.header("content-type"), "text/css; charset=utf-8")

        let js = router.route(.get("/remote.js"))
        XCTAssertEqual(js.statusCode, 200)
        XCTAssertEqual(js.header("content-type"), "application/javascript; charset=utf-8")
        XCTAssertTrue(js.bodyText.contains("/api/snapshot"))
        XCTAssertTrue(js.bodyText.contains("Authorization"))
        XCTAssertFalse(js.bodyText.contains("/api/command"))
        XCTAssertFalse(js.bodyText.localizedStandardContains("https://"))
    }

    func testSnapshotRouteRequiresAuthAndReturnsSnapshotJSON() throws {
        let router = router(snapshot: snapshot(current: "Opening", bgm: "Walk In"))

        let response = router.route(.get(
            "/api/snapshot",
            headers: ["Authorization": "Bearer token-1"]
        ))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.header("content-type"), "application/json")
        XCTAssertTrue(response.bodyText.contains(#""currentProgramTitle":"Opening""#))
        XCTAssertTrue(response.bodyText.contains(#""currentBGMTitle":"Walk In""#))
    }

    func testCommandRouteAcceptsSafeCommandsWithoutExecutingSideEffects() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        let router = router()
        let requestBody = #"{"id":"\#(id.uuidString)","kind":"takeNext"}"#.data(using: .utf8)!

        let response = router.route(.post(
            "/api/command",
            headers: ["Authorization": "Bearer token-1"],
            body: requestBody
        ))

        XCTAssertEqual(response.statusCode, 202)
        XCTAssertTrue(response.bodyText.contains(#""accepted":true"#))
        XCTAssertTrue(response.bodyText.contains(#""kind":"takeNext""#))
        XCTAssertTrue(response.bodyText.contains(#""liveModeAction":"takeNext""#))
    }

    func testSessionCloseRouteRequiresAuthAndReturnsCloseDecisionOnly() {
        let router = router()

        let response = router.route(.post(
            "/api/session/close",
            headers: ["Authorization": "Bearer token-1"]
        ))

        XCTAssertEqual(response.statusCode, 202)
        XCTAssertTrue(response.bodyText.contains(#""closeRequested":true"#))
    }

    private func router(
        snapshot: RemoteControlSnapshot? = nil,
        context: RemoteControlCommandValidationContext? = nil
    ) -> RemoteControlRequestRouter {
        RemoteControlRequestRouter(
            token: RemoteControlToken(value: "token-1"),
            snapshotProvider: {
                snapshot ?? self.snapshot(current: nil, bgm: nil)
            },
            commandContextProvider: {
                context ?? RemoteControlCommandValidationContext(
                    isRemoteEnabled: true,
                    acceptedCommandIDs: [],
                    dangerConfirmationExpirations: [:],
                    now: Date(timeIntervalSince1970: 100)
                )
            }
        )
    }

    private func snapshot(current: String?, bgm: String?) -> RemoteControlSnapshot {
        RemoteControlSnapshot(
            connectionState: .connected,
            currentProgramTitle: current,
            nextProgramTitle: "Next",
            isBroadcasting: true,
            isPanicActive: false,
            isFadeToBlackActive: false,
            isCurrentMediaPlaying: true,
            canToggleCurrentMedia: true,
            canReturnCurrentMediaToStart: true,
            currentBGMTitle: bgm,
            isBGMPlaying: true,
            canSelectPreviousBGM: true,
            canSelectNextBGM: true,
            isSpeakerMode: false,
            disabledReason: nil
        )
    }
}
