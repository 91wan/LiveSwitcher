import Foundation
import XCTest
@testable import LiveSwitcher

final class RemoteControlServerLifecycleTests: XCTestCase {
    func testServerIsDisabledByDefault() {
        let harness = ServerHarness()

        XCTAssertFalse(harness.server.isEnabled)
        XCTAssertNil(harness.server.activeSession)
        XCTAssertNil(harness.server.activeEndpoint)
        XCTAssertTrue(harness.createdListeners.isEmpty)
    }

    func testEnableStartsListenerAndRoutesPublicHealthRequest() throws {
        let harness = ServerHarness()

        let result = harness.server.enable(port: 41888, now: Date(timeIntervalSince1970: 100))

        guard case .started(let endpoint) = result else {
            return XCTFail("Expected server to start")
        }
        XCTAssertEqual(endpoint.port, 41888)
        XCTAssertEqual(endpoint.token.value, "token-1")
        XCTAssertTrue(harness.server.isEnabled)
        XCTAssertEqual(harness.server.activeSession?.token.value, "token-1")
        XCTAssertEqual(harness.createdListeners.map(\.requestedPort), [41888])
        XCTAssertEqual(harness.createdListeners.first?.startCallCount, 1)

        let rawResponse = try XCTUnwrap(harness.createdListeners.first?.respond(to: "GET /health HTTP/1.1\r\n\r\n"))
        XCTAssertTrue(rawResponse.contains("HTTP/1.1 200 OK"))
        XCTAssertTrue(rawResponse.contains(#""status":"ok""#))
    }

    func testEnableWithoutConfiguredPortUsesListenerBoundPort() {
        let harness = ServerHarness()

        let result = harness.server.enable(now: Date(timeIntervalSince1970: 100))

        guard case .started(let endpoint) = result else {
            return XCTFail("Expected server to start")
        }
        XCTAssertNil(harness.createdListeners.first?.requestedPort)
        XCTAssertEqual(endpoint.port, 41888)
    }

    func testDisableStopsListenerAndInvalidatesSession() {
        let harness = ServerHarness()
        _ = harness.server.enable(port: 41888, now: Date(timeIntervalSince1970: 100))

        harness.server.disable()

        XCTAssertFalse(harness.server.isEnabled)
        XCTAssertNil(harness.server.activeSession)
        XCTAssertNil(harness.server.activeEndpoint)
        XCTAssertEqual(harness.createdListeners.first?.cancelCallCount, 1)
    }

    func testDeinitStopsActiveListener() {
        let harness = ServerHarness()
        var server: RemoteControlServer? = RemoteControlServer(
            listenerFactory: harness.makeListener(port:),
            tokenProvider: { RemoteControlToken(value: "token-1") },
            snapshotProvider: harness.snapshot,
            commandContextProvider: harness.commandContext
        )
        _ = server?.enable(port: 41888, now: Date(timeIntervalSince1970: 100))

        server = nil

        XCTAssertEqual(harness.createdListeners.first?.cancelCallCount, 1)
    }

    func testStartFailureDoesNotKeepEnabledSessionOrLeakToken() {
        let harness = ServerHarness()
        harness.nextListenerShouldFailStart = true

        let result = harness.server.enable(port: 41888, now: Date(timeIntervalSince1970: 100))

        guard case .failed(let failure) = result else {
            return XCTFail("Expected listener start failure")
        }
        XCTAssertEqual(failure.reason, "listenerStartFailed")
        XCTAssertFalse(harness.server.isEnabled)
        XCTAssertNil(harness.server.activeSession)
        XCTAssertNil(harness.server.activeEndpoint)
        XCTAssertEqual(harness.createdListeners.first?.cancelCallCount, 1)
        XCTAssertFalse(harness.server.redactedDiagnosticsSummary.contains("token-1"))
        XCTAssertFalse(failure.reason.contains("token-1"))
    }

    func testRuntimeListenerFailureDisablesSessionWithoutLeakingToken() {
        let harness = ServerHarness()
        _ = harness.server.enable(port: 41888, now: Date(timeIntervalSince1970: 100))

        harness.createdListeners.first?.failRuntime()

        XCTAssertFalse(harness.server.isEnabled)
        XCTAssertNil(harness.server.activeSession)
        XCTAssertNil(harness.server.activeEndpoint)
        XCTAssertFalse(harness.server.redactedDiagnosticsSummary.contains("token-1"))
    }

    func testSessionCloseRequestDisablesServerAndInvalidatesOldToken() throws {
        let harness = ServerHarness()
        _ = harness.server.enable(port: 41888, now: Date(timeIntervalSince1970: 100))

        let closeResponse = try XCTUnwrap(harness.createdListeners.first?.respond(to: rawSessionCloseRequest(token: "token-1")))

        XCTAssertTrue(closeResponse.contains("HTTP/1.1 202 Accepted"))
        XCTAssertTrue(closeResponse.contains(#""closeRequested":true"#))
        XCTAssertTrue(closeResponse.contains(#""closed":true"#))
        XCTAssertFalse(closeResponse.contains("token-1"))
        XCTAssertFalse(harness.server.isEnabled)
        XCTAssertNil(harness.server.activeSession)
        XCTAssertNil(harness.server.activeEndpoint)
        XCTAssertEqual(harness.createdListeners.first?.cancelCallCount, 1)

        let oldTokenSnapshot = try XCTUnwrap(harness.createdListeners.first?.respond(to: rawSnapshotRequest(token: "token-1")))
        XCTAssertTrue(oldTokenSnapshot.contains("HTTP/1.1 403 Forbidden"))
        XCTAssertTrue(oldTokenSnapshot.contains(#""error":"invalidAuthorization""#))
        XCTAssertFalse(oldTokenSnapshot.contains("Opening"))
        XCTAssertFalse(oldTokenSnapshot.contains("token-1"))
    }

    func testSessionCloseClearsAcceptedCommandIDsAndDangerConfirmations() throws {
        let harness = ServerHarness()
        harness.tokens = [
            RemoteControlToken(value: "token-1"),
            RemoteControlToken(value: "token-2")
        ]
        _ = harness.server.enable(port: 41888, now: Date(timeIntervalSince1970: 100))
        let commandID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        let firstCommand = try XCTUnwrap(harness.createdListeners.first?.respond(to: rawCommandRequest(token: "token-1", id: commandID)))
        let challengeResponse = try XCTUnwrap(harness.createdListeners.first?.respond(to: rawDangerConfirmationRequest(token: "token-1")))
        let nonce = try nonce(fromHTTPResponse: challengeResponse)
        let closeResponse = try XCTUnwrap(harness.createdListeners.first?.respond(to: rawSessionCloseRequest(token: "token-1")))
        _ = harness.server.enable(port: 41888, now: Date(timeIntervalSince1970: 200))

        let reusedCommandID = try XCTUnwrap(harness.createdListeners.last?.respond(to: rawCommandRequest(token: "token-2", id: commandID)))
        let oldNonceCommand = try XCTUnwrap(harness.createdListeners.last?.respond(to: rawDangerousCommandRequest(token: "token-2", nonce: nonce)))

        XCTAssertTrue(firstCommand.contains("HTTP/1.1 202 Accepted"))
        XCTAssertTrue(closeResponse.contains("HTTP/1.1 202 Accepted"))
        XCTAssertTrue(reusedCommandID.contains("HTTP/1.1 202 Accepted"))
        XCTAssertFalse(reusedCommandID.contains("duplicateCommandID"))
        XCTAssertTrue(oldNonceCommand.contains("HTTP/1.1 409 Conflict"))
        XCTAssertTrue(oldNonceCommand.contains(#""error":"unknownDangerConfirmation""#))
    }
}

private final class ServerHarness {
    var createdListeners: [FakeRemoteControlListener] = []
    var nextListenerShouldFailStart = false
    var tokens = [RemoteControlToken(value: "token-1")]

    lazy var server = RemoteControlServer(
        listenerFactory: makeListener(port:),
        tokenProvider: { [weak self] in
            guard let self else { return RemoteControlToken(value: "token-1") }
            if self.tokens.count > 1 {
                return self.tokens.removeFirst()
            }
            return self.tokens.first ?? RemoteControlToken(value: "token-1")
        },
        snapshotProvider: snapshot,
        commandContextProvider: commandContext
    )

    func makeListener(port: UInt16?) throws -> RemoteControlListening {
        let listener = FakeRemoteControlListener(
            requestedPort: port,
            boundPort: port ?? 41888,
            shouldFailStart: nextListenerShouldFailStart
        )
        nextListenerShouldFailStart = false
        createdListeners.append(listener)
        return listener
    }

    func snapshot() -> RemoteControlSnapshot {
        RemoteControlSnapshot(
            connectionState: .connected,
            currentProgramTitle: "Opening",
            nextProgramTitle: "Next",
            isBroadcasting: true,
            isPanicActive: false,
            isFadeToBlackActive: false,
            isCurrentMediaPlaying: true,
            canToggleCurrentMedia: true,
            canReturnCurrentMediaToStart: true,
            currentBGMTitle: "Walk In",
            isBGMPlaying: true,
            canSelectPreviousBGM: true,
            canSelectNextBGM: true,
            isSpeakerMode: false,
            disabledReason: nil
        )
    }

    func commandContext() -> RemoteControlCommandValidationContext {
        RemoteControlCommandValidationContext(
            isRemoteEnabled: true,
            acceptedCommandIDs: [],
            dangerConfirmationChallenges: [:],
            now: Date(timeIntervalSince1970: 100)
        )
    }
}

private final class FakeRemoteControlListener: RemoteControlListening {
    let requestedPort: UInt16?
    let boundPort: UInt16
    let shouldFailStart: Bool
    var requestHandler: ((String) -> Data)?
    var failureHandler: (() -> Void)?
    private(set) var startCallCount = 0
    private(set) var cancelCallCount = 0

    var port: UInt16? {
        boundPort
    }

    init(requestedPort: UInt16?, boundPort: UInt16, shouldFailStart: Bool) {
        self.requestedPort = requestedPort
        self.boundPort = boundPort
        self.shouldFailStart = shouldFailStart
    }

    func start() throws {
        startCallCount += 1
        if shouldFailStart {
            throw FakeListenerError.startFailed
        }
    }

    func cancel() {
        cancelCallCount += 1
    }

    func respond(to rawRequest: String) -> String? {
        guard let data = requestHandler?(rawRequest) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func failRuntime() {
        failureHandler?()
    }
}

private enum FakeListenerError: Error {
    case startFailed
}

private func rawSnapshotRequest(token: String) -> String {
    """
    GET /api/snapshot HTTP/1.1\r
    Authorization: Bearer \(token)\r
    \r

    """
}

private func rawSessionCloseRequest(token: String) -> String {
    """
    POST /api/session/close HTTP/1.1\r
    Authorization: Bearer \(token)\r
    Content-Length: 2\r
    \r
    {}
    """
}

private func rawCommandRequest(token: String, id: UUID, kind: String = "takeNext") -> String {
    let body = #"{"id":"\#(id.uuidString)","kind":"\#(kind)"}"#
    return """
    POST /api/command HTTP/1.1\r
    Authorization: Bearer \(token)\r
    Content-Length: \(body.utf8.count)\r
    \r
    \(body)
    """
}

private func rawDangerConfirmationRequest(token: String) -> String {
    let body = #"{"kind":"togglePanic"}"#
    return """
    POST /api/danger-confirmation HTTP/1.1\r
    Authorization: Bearer \(token)\r
    Content-Length: \(body.utf8.count)\r
    \r
    \(body)
    """
}

private func rawDangerousCommandRequest(token: String, nonce: String) -> String {
    let body = #"{"id":"22222222-2222-2222-2222-222222222222","kind":"togglePanic","confirmation":{"nonce":"\#(nonce)"}}"#
    return """
    POST /api/command HTTP/1.1\r
    Authorization: Bearer \(token)\r
    Content-Length: \(body.utf8.count)\r
    \r
    \(body)
    """
}

private func nonce(fromHTTPResponse rawResponse: String) throws -> String {
    let body = try XCTUnwrap(rawResponse.components(separatedBy: "\r\n\r\n").last)
    let data = try XCTUnwrap(body.data(using: .utf8))
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    return try XCTUnwrap(object["nonce"] as? String)
}
