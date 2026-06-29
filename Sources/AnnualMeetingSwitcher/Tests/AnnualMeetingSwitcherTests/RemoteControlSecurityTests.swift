import XCTest
@testable import LiveSwitcher

final class RemoteControlSecurityTests: XCTestCase {
    func testAPIWithoutTokenReturns401AndDoesNotLeakToken() {
        let router = router()

        let response = router.route(.get("/api/snapshot"))

        XCTAssertEqual(response.statusCode, 401)
        XCTAssertFalse(response.bodyText.contains("token-1"))
        XCTAssertTrue(response.bodyText.contains("missingAuthorization"))
    }

    func testAPIWithBadTokenReturns403AndDoesNotLeakToken() {
        let router = router()

        let response = router.route(.get(
            "/api/snapshot",
            headers: ["Authorization": "Bearer wrong-token"]
        ))

        XCTAssertEqual(response.statusCode, 403)
        XCTAssertFalse(response.bodyText.contains("token-1"))
        XCTAssertFalse(response.bodyText.contains("wrong-token"))
        XCTAssertTrue(response.bodyText.contains("invalidAuthorization"))
    }

    func testBadJSONReturnsSafeError() {
        let router = router()

        let response = router.route(.post(
            "/api/command",
            headers: ["Authorization": "Bearer token-1"],
            body: Data(#"{"kind":"takeNext","token":"token-1","title":"VIP Customer"}"#.utf8)
        ))

        XCTAssertEqual(response.statusCode, 400)
        XCTAssertTrue(response.bodyText.contains("invalidCommandJSON"))
        XCTAssertFalse(response.bodyText.contains("token-1"))
        XCTAssertFalse(response.bodyText.contains("VIP Customer"))
    }

    func testForbiddenAndOutOfScopeCommandsAreRejectedBeforeExecution() {
        let router = router()

        let editResponse = router.route(commandKind: "editBGMLibrary")
        XCTAssertEqual(editResponse.statusCode, 403)
        XCTAssertTrue(editResponse.bodyText.contains("forbiddenConfigurationCommand"))

        let projectionResponse = router.route(commandKind: "toggleProjection")
        XCTAssertEqual(projectionResponse.statusCode, 403)
        XCTAssertTrue(projectionResponse.bodyText.contains("commandNotInRemoteMVP"))
    }

    func testDangerousCommandWithoutConfirmationIsRejected() {
        let router = router()

        let response = router.route(commandKind: "togglePanic")

        XCTAssertEqual(response.statusCode, 409)
        XCTAssertTrue(response.bodyText.contains("missingDangerConfirmation"))
    }

    func testPathTraversalAndUnsupportedMethodsAreRejectedSafely() {
        let router = router()

        let traversal = router.route(.get("/../api/snapshot"))
        XCTAssertEqual(traversal.statusCode, 404)

        let unsupported = router.route(RemoteControlHTTPRequest(
            method: .put,
            path: "/api/snapshot",
            headers: ["Authorization": "Bearer token-1"],
            body: Data()
        ))
        XCTAssertEqual(unsupported.statusCode, 405)
    }

    private func router() -> RemoteControlRequestRouter {
        RemoteControlRequestRouter(
            token: RemoteControlToken(value: "token-1"),
            snapshotProvider: {
                RemoteControlSnapshot(
                    connectionState: .connected,
                    currentProgramTitle: "VIP Customer Opening",
                    nextProgramTitle: "CEO Guest Speech",
                    isBroadcasting: true,
                    isPanicActive: false,
                    isFadeToBlackActive: false,
                    isCurrentMediaPlaying: true,
                    canToggleCurrentMedia: true,
                    canReturnCurrentMediaToStart: true,
                    currentBGMTitle: "Private BGM",
                    isBGMPlaying: true,
                    canSelectPreviousBGM: true,
                    canSelectNextBGM: true,
                    isSpeakerMode: false,
                    disabledReason: nil
                )
            },
            commandContextProvider: {
                RemoteControlCommandValidationContext(
                    isRemoteEnabled: true,
                    acceptedCommandIDs: [],
                    dangerConfirmationExpirations: [:],
                    now: Date(timeIntervalSince1970: 100)
                )
            }
        )
    }
}

private extension RemoteControlRequestRouter {
    func route(commandKind: String) -> RemoteControlHTTPResponse {
        let body = #"{"id":"00000000-0000-0000-0000-000000000321","kind":"\#(commandKind)"}"#.data(using: .utf8)!
        return route(.post(
            "/api/command",
            headers: ["Authorization": "Bearer token-1"],
            body: body
        ))
    }
}
