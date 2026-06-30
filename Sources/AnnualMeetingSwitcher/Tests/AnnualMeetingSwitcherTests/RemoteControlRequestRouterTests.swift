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
        XCTAssertTrue(page.bodyText.contains("data-command"))
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
        XCTAssertTrue(js.bodyText.contains("/api/command"))
        XCTAssertTrue(js.bodyText.contains("/api/danger-confirmation"))
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

    func testCommandRouteExecutesSafeCommandsThroughInjectedExecutor() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        var executedCommands: [RemoteControlAcceptedCommand] = []
        let router = router(commandExecutor: { command in
            executedCommands.append(command)
            return .executed(RemoteControlCommandExecutionRecord(command: command))
        })
        let requestBody = #"{"id":"\#(id.uuidString)","kind":"takeNext"}"#.data(using: .utf8)!

        let response = router.route(.post(
            "/api/command",
            headers: ["Authorization": "Bearer token-1"],
            body: requestBody
        ))

        XCTAssertEqual(response.statusCode, 202)
        XCTAssertEqual(executedCommands.map(\.kind), [.takeNext])
        XCTAssertTrue(response.bodyText.contains(#""accepted":true"#))
        XCTAssertTrue(response.bodyText.contains(#""executed":true"#))
        XCTAssertTrue(response.bodyText.contains(#""action":"takeNext""#))
        XCTAssertTrue(response.bodyText.contains(#""liveModeAction":"takeNext""#))
    }

    func testDangerConfirmationRouteRequiresAuthAndDangerousKindThenIssuesBoundNonce() {
        var issuedKinds: [RemoteControlCommandKind] = []
        var issuedNonceCount = 0
        let router = router(dangerConfirmationIssuer: { kind in
            issuedKinds.append(kind)
            issuedNonceCount += 1
            return RemoteDangerConfirmationChallenge(
                nonce: "nonce-1",
                commandKind: kind,
                issuedAt: Date(timeIntervalSince1970: 100),
                expiresAt: Date(timeIntervalSince1970: 105),
                consumedAt: nil
            )
        })

        let unauthorized = router.route(.post("/api/danger-confirmation"))
        XCTAssertEqual(unauthorized.statusCode, 401)
        XCTAssertEqual(issuedNonceCount, 0)

        let response = router.route(.post(
            "/api/danger-confirmation",
            headers: ["Authorization": "Bearer token-1"],
            body: Data(#"{"kind":"togglePanic"}"#.utf8)
        ))

        XCTAssertEqual(response.statusCode, 202)
        XCTAssertEqual(issuedNonceCount, 1)
        XCTAssertEqual(issuedKinds, [.togglePanic])
        XCTAssertTrue(response.bodyText.contains(#""nonce":"nonce-1""#))
        XCTAssertTrue(response.bodyText.contains(#""minimumHoldDuration":1"#))
        XCTAssertTrue(response.bodyText.contains(#""expiresAt":105"#))
        XCTAssertFalse(response.bodyText.contains("token-1"))

        let safeKind = router.route(.post(
            "/api/danger-confirmation",
            headers: ["Authorization": "Bearer token-1"],
            body: Data(#"{"kind":"takeNext"}"#.utf8)
        ))

        XCTAssertEqual(safeKind.statusCode, 409)
        XCTAssertTrue(safeKind.bodyText.contains("dangerConfirmationNotRequired"))
    }

    func testCommandRouteAcceptsNonceOnlyDangerConfirmationAfterServerElapsedHold() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000456")!
        var executedCommands: [RemoteControlAcceptedCommand] = []
        let router = router(
            context: RemoteControlCommandValidationContext(
                isRemoteEnabled: true,
                acceptedCommandIDs: [],
                dangerConfirmationChallenges: [
                    "nonce-1": RemoteDangerConfirmationChallenge(
                        nonce: "nonce-1",
                        commandKind: .togglePanic,
                        issuedAt: Date(timeIntervalSince1970: 98.8),
                        expiresAt: Date(timeIntervalSince1970: 105),
                        consumedAt: nil
                    )
                ],
                now: Date(timeIntervalSince1970: 100)
            ),
            commandExecutor: { command in
                executedCommands.append(command)
                return .executed(RemoteControlCommandExecutionRecord(command: command))
            }
        )

        let response = router.route(.post(
            "/api/command",
            headers: ["Authorization": "Bearer token-1"],
            body: Data(#"{"id":"\#(id.uuidString)","kind":"togglePanic","confirmation":{"nonce":"nonce-1"}}"#.utf8)
        ))

        XCTAssertEqual(response.statusCode, 202)
        XCTAssertEqual(executedCommands.map(\.dangerConfirmationNonce), ["nonce-1"])
    }

    func testCommandRouteRejectsSpoofedHoldDurationBeforeServerElapsedHold() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000789")!
        var executedCommands: [RemoteControlAcceptedCommand] = []
        let router = router(
            context: RemoteControlCommandValidationContext(
                isRemoteEnabled: true,
                acceptedCommandIDs: [],
                dangerConfirmationChallenges: [
                    "nonce-1": RemoteDangerConfirmationChallenge(
                        nonce: "nonce-1",
                        commandKind: .togglePanic,
                        issuedAt: Date(timeIntervalSince1970: 99.8),
                        expiresAt: Date(timeIntervalSince1970: 105),
                        consumedAt: nil
                    )
                ],
                now: Date(timeIntervalSince1970: 100)
            ),
            commandExecutor: { command in
                executedCommands.append(command)
                return .executed(RemoteControlCommandExecutionRecord(command: command))
            }
        )

        let response = router.route(.post(
            "/api/command",
            headers: ["Authorization": "Bearer token-1"],
            body: Data(#"{"id":"\#(id.uuidString)","kind":"togglePanic","confirmation":{"nonce":"nonce-1","holdDuration":99.0}}"#.utf8)
        ))

        XCTAssertEqual(response.statusCode, 409)
        XCTAssertTrue(response.bodyText.contains("insufficientDangerHoldDuration"))
        XCTAssertTrue(executedCommands.isEmpty)
    }

    func testSessionCloseRouteRequiresAuthAndInvokesCloseHandler() {
        var closeCallCount = 0
        let router = router(sessionCloseHandler: {
            closeCallCount += 1
            return .closed
        })

        let unauthorized = router.route(.post("/api/session/close"))
        XCTAssertEqual(unauthorized.statusCode, 401)
        XCTAssertEqual(closeCallCount, 0)

        let response = router.route(.post(
            "/api/session/close",
            headers: ["Authorization": "Bearer token-1"]
        ))

        XCTAssertEqual(response.statusCode, 202)
        XCTAssertTrue(response.bodyText.contains(#""closeRequested":true"#))
        XCTAssertTrue(response.bodyText.contains(#""closed":true"#))
        XCTAssertFalse(response.bodyText.contains("token-1"))
        XCTAssertEqual(closeCallCount, 1)
    }

    private func router(
        snapshot: RemoteControlSnapshot? = nil,
        context: RemoteControlCommandValidationContext? = nil,
        dangerConfirmationIssuer: @escaping (RemoteControlCommandKind) -> RemoteDangerConfirmationChallenge? = { _ in nil },
        sessionCloseHandler: @escaping () -> RemoteControlSessionCloseResult = { .remoteDisabled },
        commandExecutor: @escaping (RemoteControlAcceptedCommand) -> RemoteControlCommandExecutionResult = {
            .executed(RemoteControlCommandExecutionRecord(command: $0))
        }
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
                    dangerConfirmationChallenges: [:],
                    now: Date(timeIntervalSince1970: 100)
                )
            },
            dangerConfirmationIssuer: dangerConfirmationIssuer,
            sessionCloseHandler: sessionCloseHandler,
            commandExecutor: commandExecutor
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
