import Foundation
import XCTest
@testable import LiveSwitcher

@MainActor
final class RemoteControlCommandExecutionTests: XCTestCase {
    func testRouterExecutesAcceptedCommandAndReturnsSanitizedRecord() {
        let commandID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        var executedCommands: [RemoteControlAcceptedCommand] = []
        let router = router { command in
            executedCommands.append(command)
            return .executed(RemoteControlCommandExecutionRecord(command: command))
        }

        let response = router.route(commandRequest(id: commandID, kind: "takeNext"))

        XCTAssertEqual(response.statusCode, 202)
        XCTAssertEqual(executedCommands.map(\.kind), [.takeNext])
        XCTAssertTrue(response.bodyText.contains(#""executed":true"#))
        XCTAssertTrue(response.bodyText.contains(#""action":"takeNext""#))
        XCTAssertFalse(response.bodyText.contains("Opening"))
        XCTAssertFalse(response.bodyText.contains("Walk-in"))
        XCTAssertFalse(response.bodyText.contains("token-1"))
    }

    func testServerRecordsAcceptedCommandIDsAndRejectsDuplicateBeforeExecution() throws {
        let harness = RemoteCommandServerHarness()
        _ = harness.server.enable(port: 41888, now: Date(timeIntervalSince1970: 100))

        let first = try XCTUnwrap(harness.createdListeners.first?.respond(to: rawCommandRequest(id: fixedCommandID)))
        let duplicate = try XCTUnwrap(harness.createdListeners.first?.respond(to: rawCommandRequest(id: fixedCommandID)))

        XCTAssertTrue(first.contains("HTTP/1.1 202 Accepted"))
        XCTAssertTrue(duplicate.contains("HTTP/1.1 409 Conflict"))
        XCTAssertTrue(duplicate.contains(#""error":"duplicateCommandID""#))
        XCTAssertEqual(harness.executedCommands.map(\.kind), [.takeNext])
    }

    func testServerIssuedDangerConfirmationEnablesLongPressDangerousCommand() throws {
        let harness = RemoteCommandServerHarness()
        _ = harness.server.enable(port: 41888, now: Date(timeIntervalSince1970: 100))

        let challengeResponse = try XCTUnwrap(harness.createdListeners.first?.respond(to: rawDangerConfirmationRequest()))
        XCTAssertTrue(challengeResponse.contains("HTTP/1.1 202 Accepted"))
        XCTAssertFalse(challengeResponse.contains("token-1"))

        let nonce = try nonce(fromHTTPResponse: challengeResponse)
        let commandResponse = try XCTUnwrap(harness.createdListeners.first?.respond(to: rawDangerousCommandRequest(nonce: nonce)))

        XCTAssertTrue(commandResponse.contains("HTTP/1.1 202 Accepted"))
        XCTAssertTrue(commandResponse.contains(#""action":"togglePanic""#))
        XCTAssertTrue(commandResponse.contains(#""dangerous":true"#))
        XCTAssertEqual(harness.executedCommands.map(\.kind), [.togglePanic])
    }

    func testSetupControllerEnablesCommandExecutionBridge() throws {
        let harness = RemoteControlSetupExecutionHarness()
        let current = try videoProgram(title: "Current")
        let next = try videoProgram(title: "Next")
        harness.viewModel.applyProgramQueueProjectionFromRuntime([current, next])
        harness.viewModel.applyCurrentProgramProjectionFromRuntime(current, switchedAt: Date())
        harness.viewModel.runtime.replaceStateForFacadeSync(
            runtimeState(current: current, items: [current, next]),
            clearActionLog: true
        )

        harness.viewModel.remoteControlSetup.enable()
        let response = harness.createdListeners.first?.respond(to: rawCommandRequest(id: fixedCommandID))

        XCTAssertTrue(response?.contains("HTTP/1.1 202 Accepted") == true)
        XCTAssertEqual(actionCount("operatorRequestedProgramActivation", in: harness.viewModel), 1)
        XCTAssertFalse(response?.contains("remoteDisabled") == true)
    }

    func testViewModelMapsRemoteCommandsToExistingFacadeMethods() throws {
        let viewModel = makeViewModel()
        let video = try videoProgram()
        let bgm = BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"), category: .warmUp)
        viewModel.bgmItems = [bgm]
        viewModel.bgmLibraryCategorySelection.selectedCategory = .warmUp
        viewModel.applyCurrentProgramProjectionFromRuntime(video, switchedAt: Date())
        viewModel.runtime.replaceStateForFacadeSync(runtimeState(current: video, items: [video]), clearActionLog: true)

        _ = viewModel.executeRemoteControlCommand(accepted(.toggleCurrentMediaPlayback))
        _ = viewModel.executeRemoteControlCommand(accepted(.returnCurrentMediaToStart))
        _ = viewModel.executeRemoteControlCommand(accepted(.toggleBGMPlayback))
        _ = viewModel.executeRemoteControlCommand(accepted(.selectNextBGM))
        _ = viewModel.executeRemoteControlCommand(accepted(.selectPreviousBGM))
        _ = viewModel.executeRemoteControlCommand(accepted(.toggleSpeakerMode))
        _ = viewModel.executeRemoteControlCommand(accepted(.toggleFadeToBlack))
        _ = viewModel.executeRemoteControlCommand(accepted(.togglePanic))

        XCTAssertEqual(actionCount("operatorToggledMediaPlayback", in: viewModel), 1)
        XCTAssertEqual(actionCount("operatorReturnedCurrentMediaToStart", in: viewModel), 1)
        XCTAssertEqual(actionCount("operatorSelectedBGM", in: viewModel), 1)
        XCTAssertEqual(actionCount("operatorSelectedNextBGM", in: viewModel), 1)
        XCTAssertEqual(actionCount("operatorSelectedPreviousBGM", in: viewModel), 1)
        XCTAssertTrue(viewModel.isSpeakerMode)
        XCTAssertTrue(viewModel.isFadeToBlackActive)
        XCTAssertTrue(viewModel.outputPanicIsActive)
    }

    func testRemoteHTTPLayerDoesNotMutateViewModelStateDirectly() throws {
        let routerSource = try sourceText("RemoteControl/RemoteControlRequestRouter.swift")
        let serverSource = try sourceText("RemoteControl/RemoteControlServer.swift")

        XCTAssertFalse(routerSource.contains("SwitcherViewModel"))
        XCTAssertFalse(routerSource.contains("switchToProgram"))
        XCTAssertFalse(routerSource.contains("toggleMainVideoPlayback"))
        XCTAssertFalse(serverSource.contains("SwitcherViewModel"))
        XCTAssertFalse(serverSource.contains("switchToProgram"))
        XCTAssertFalse(serverSource.contains("toggleMainVideoPlayback"))
    }

    private var fixedCommandID: UUID {
        UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    }

    private func router(
        executor: @escaping (RemoteControlAcceptedCommand) -> RemoteControlCommandExecutionResult
    ) -> RemoteControlRequestRouter {
        RemoteControlRequestRouter(
            token: RemoteControlToken(value: "token-1"),
            snapshotProvider: { .remoteExecutionTestSnapshot },
            commandContextProvider: {
                RemoteControlCommandValidationContext(
                    isRemoteEnabled: true,
                    acceptedCommandIDs: [],
                    dangerConfirmationExpirations: [:],
                    now: Date(timeIntervalSince1970: 100)
                )
            },
            commandExecutor: executor
        )
    }

    private func commandRequest(id: UUID, kind: String) -> RemoteControlHTTPRequest {
        .post(
            "/api/command",
            headers: ["Authorization": "Bearer token-1"],
            body: Data(#"{"id":"\#(id.uuidString)","kind":"\#(kind)"}"#.utf8)
        )
    }

    private func rawCommandRequest(id: UUID, kind: String = "takeNext") -> String {
        """
        POST /api/command HTTP/1.1\r
        Authorization: Bearer token-1\r
        Content-Length: 65\r
        \r
        {"id":"\(id.uuidString)","kind":"\(kind)"}
        """
    }

    private func rawDangerConfirmationRequest() -> String {
        """
        POST /api/danger-confirmation HTTP/1.1\r
        Authorization: Bearer token-1\r
        Content-Length: 2\r
        \r
        {}
        """
    }

    private func rawDangerousCommandRequest(nonce: String) -> String {
        """
        POST /api/command HTTP/1.1\r
        Authorization: Bearer token-1\r
        Content-Length: 160\r
        \r
        {"id":"\(fixedCommandID.uuidString)","kind":"togglePanic","confirmation":{"nonce":"\(nonce)","holdDuration":1.2}}
        """
    }

    private func nonce(fromHTTPResponse rawResponse: String) throws -> String {
        let body = try XCTUnwrap(rawResponse.components(separatedBy: "\r\n\r\n").last)
        let data = try XCTUnwrap(body.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(object["nonce"] as? String)
    }

    private func accepted(_ kind: RemoteControlCommandKind) -> RemoteControlAcceptedCommand {
        RemoteControlAcceptedCommand(
            id: UUID(),
            kind: kind,
            liveModeAction: kind.liveModeAction,
            isDangerous: kind.isDangerous
        )
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "RemoteControlCommandExecutionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        viewModel.liveAudioFadeDuration = 0
        return viewModel
    }

    private func videoProgram(title: String = "Video") throws -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try Data("fixture".utf8).write(to: url)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return ProgramItem(
            title: title,
            subtitle: "VIDEO",
            sourceURL: url
        )
    }

    private func runtimeState(current: ProgramItem, items: [ProgramItem]) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = items
        state.program.currentID = current.id
        state.media.loadedURL = current.sourceURL
        state.media.duration = 10
        state.audio.routingContext.isCurrentProgramMediaSource = true
        return state
    }

    private func actionCount(_ name: String, in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.actionLog.filter { $0.actionName == name }.count
    }
}

private final class RemoteCommandServerHarness {
    var createdListeners: [FakeRemoteCommandListener] = []
    var executedCommands: [RemoteControlAcceptedCommand] = []

    lazy var server = RemoteControlServer(
        listenerFactory: makeListener(port:),
        tokenProvider: { RemoteControlToken(value: "token-1") },
        snapshotProvider: { .remoteExecutionTestSnapshot },
        commandContextProvider: {
            RemoteControlCommandValidationContext(
                isRemoteEnabled: true,
                acceptedCommandIDs: [],
                dangerConfirmationExpirations: [:],
                now: Date(timeIntervalSince1970: 100)
            )
        },
        commandExecutor: { [weak self] command in
            self?.executedCommands.append(command)
            return .executed(RemoteControlCommandExecutionRecord(command: command))
        }
    )

    func makeListener(port: UInt16?) throws -> RemoteControlListening {
        let listener = FakeRemoteCommandListener(requestedPort: port, boundPort: port ?? 41888)
        createdListeners.append(listener)
        return listener
    }
}

@MainActor
private final class RemoteControlSetupExecutionHarness {
    let viewModel: SwitcherViewModel
    var createdListeners: [FakeRemoteCommandListener] = []

    init() {
        let suiteName = "RemoteControlSetupExecutionHarness.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
        viewModel.remoteControlSetup.localAddressProvider = { "192.168.1.23" }
        viewModel.remoteControlSetup.tokenProvider = { RemoteControlToken(value: "token-1") }
        viewModel.remoteControlSetup.portProvider = { 41888 }
        viewModel.remoteControlSetup.listenerFactory = makeListener(port:)
    }

    func makeListener(port: UInt16?) throws -> RemoteControlListening {
        let listener = FakeRemoteCommandListener(requestedPort: port, boundPort: port ?? 41888)
        createdListeners.append(listener)
        return listener
    }
}

private final class FakeRemoteCommandListener: RemoteControlListening {
    let requestedPort: UInt16?
    let boundPort: UInt16
    var requestHandler: ((String) -> Data)?
    var failureHandler: (() -> Void)?
    private(set) var startCallCount = 0
    private(set) var cancelCallCount = 0

    var port: UInt16? {
        boundPort
    }

    init(requestedPort: UInt16?, boundPort: UInt16) {
        self.requestedPort = requestedPort
        self.boundPort = boundPort
    }

    func start() throws {
        startCallCount += 1
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
}

private extension RemoteControlSnapshot {
    static var remoteExecutionTestSnapshot: RemoteControlSnapshot {
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
            currentBGMTitle: "Walk-in",
            isBGMPlaying: true,
            canSelectPreviousBGM: true,
            canSelectNextBGM: true,
            isSpeakerMode: false,
            disabledReason: nil
        )
    }
}
