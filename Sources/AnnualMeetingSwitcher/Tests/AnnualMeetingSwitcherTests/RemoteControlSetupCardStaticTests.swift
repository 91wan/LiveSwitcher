import Foundation
import XCTest
@testable import LiveSwitcher

@MainActor
final class RemoteControlSetupCardStaticTests: XCTestCase {
    func testSetupCardSourceContainsPairingControlsAndQRCodeGenerator() throws {
        let source = try sourceText("Views/RemoteControlSetupCard.swift")

        XCTAssertTrue(source.contains("struct RemoteControlSetupCard"))
        XCTAssertTrue(source.contains("CIQRCodeGenerator"))
        XCTAssertTrue(source.contains("开启遥控"))
        XCTAssertTrue(source.contains("关闭遥控"))
        XCTAssertTrue(source.contains("复制链接"))
        XCTAssertTrue(source.contains("局域网地址"))
    }

    func testSetupCardIsMountedInSetupRailButNotLiveModeConfiguration() throws {
        let setupRail = try sourceText("Views/LiveOpsPanel.swift")
        let liveMode = try [
            "Views/LiveModeView.swift",
            "Views/LiveSourceRail.swift",
            "Views/LiveQuickRail.swift",
            "Views/LiveQuickRail+BGM.swift",
            "Views/LiveQuickRail+Overlays.swift"
        ].map { try sourceText($0) }.joined(separator: "\n")

        XCTAssertTrue(setupRail.contains("RemoteControlSetupCard"))
        XCTAssertFalse(liveMode.contains("RemoteControlSetupCard"))
        XCTAssertFalse(liveMode.contains("开启遥控"))
        XCTAssertFalse(liveMode.contains("复制链接"))
    }

    func testPairingURLKeepsTokenInFragment() {
        let url = RemoteControlPairingURLBuilder.pairingURL(
            host: "192.168.1.23",
            endpoint: RemoteControlServerEndpoint(
                port: 41888,
                token: RemoteControlToken(value: "token-1")
            )
        )

        XCTAssertEqual(url, "http://192.168.1.23:41888/#token=token-1")
        XCTAssertFalse(url.contains("?token="))
    }

    func testSessionPortPolicyUsesNonZeroHighPortRange() {
        let ports = (0..<20).map { _ in RemoteControlPortPolicy.makeSessionPort() }

        XCTAssertTrue(ports.allSatisfy { $0 >= 41_000 && $0 <= 60_999 })
        XCTAssertFalse(ports.contains(0))
    }

    func testViewModelRemoteControlIsDisabledByDefault() {
        let harness = RemoteControlSetupHarness()

        XCTAssertFalse(harness.viewModel.remoteControlSetup.state.isEnabled)
        XCTAssertNil(harness.viewModel.remoteControlSetup.state.pairingURL)
        XCTAssertTrue(harness.createdListeners.isEmpty)
    }

    func testViewModelEnableRemoteControlStartsServerAndBuildsPairingURL() {
        let harness = RemoteControlSetupHarness()

        harness.viewModel.remoteControlSetup.enable()

        XCTAssertTrue(harness.viewModel.remoteControlSetup.state.isEnabled)
        XCTAssertEqual(harness.createdListeners.first?.startCallCount, 1)
        XCTAssertEqual(harness.viewModel.remoteControlSetup.state.displayAddress, "192.168.1.23:41888")
        XCTAssertEqual(harness.viewModel.remoteControlSetup.state.pairingURL, "http://192.168.1.23:41888/#token=token-1")
    }

    func testViewModelEnableRemoteControlFallsBackToRequestedPortWhenListenerReportsZero() {
        let harness = RemoteControlSetupHarness()
        harness.nextBoundPort = 0

        harness.viewModel.remoteControlSetup.enable()

        XCTAssertEqual(harness.viewModel.remoteControlSetup.state.displayAddress, "192.168.1.23:41888")
        XCTAssertEqual(harness.viewModel.remoteControlSetup.state.pairingURL, "http://192.168.1.23:41888/#token=token-1")
    }

    func testViewModelDisableRemoteControlStopsServerAndClearsPairingURL() {
        let harness = RemoteControlSetupHarness()
        harness.viewModel.remoteControlSetup.enable()

        harness.viewModel.remoteControlSetup.disable()

        XCTAssertFalse(harness.viewModel.remoteControlSetup.state.isEnabled)
        XCTAssertNil(harness.viewModel.remoteControlSetup.state.pairingURL)
        XCTAssertEqual(harness.createdListeners.first?.cancelCallCount, 1)
    }

    func testViewModelStartFailureDoesNotExposePairingToken() {
        let harness = RemoteControlSetupHarness()
        harness.nextListenerShouldFailStart = true

        harness.viewModel.remoteControlSetup.enable()

        XCTAssertFalse(harness.viewModel.remoteControlSetup.state.isEnabled)
        XCTAssertNil(harness.viewModel.remoteControlSetup.state.pairingURL)
        XCTAssertFalse(harness.viewModel.remoteControlSetup.state.statusText.contains("token-1"))
    }

    func testViewModelRemoteCommandBridgeAcceptsCommandsAfterEnable() {
        let harness = RemoteControlSetupHarness()
        harness.viewModel.remoteControlSetup.enable()

        _ = harness.createdListeners.first?.respond(to: """
        POST /api/session/claim HTTP/1.1\r
        Authorization: Bearer token-1\r
        Content-Length: 22\r
        \r
        {"clientID":"phone-a"}
        """)
        let response = harness.createdListeners.first?.respond(to: """
        POST /api/command HTTP/1.1\r
        Authorization: Bearer token-1\r
        X-Remote-Client-ID: phone-a\r
        Content-Length: 65\r
        \r
        {"id":"11111111-1111-1111-1111-111111111111","kind":"takeNext"}
        """)

        XCTAssertTrue(response?.contains("HTTP/1.1 202 Accepted") == true)
        XCTAssertTrue(response?.contains(#""executed":true"#) == true)
        XCTAssertTrue(response?.contains(#""action":"takeNext""#) == true)
        XCTAssertFalse(response?.contains("remoteDisabled") == true)
        XCTAssertFalse(response?.contains("token-1") == true)
    }

    func testViewModelRemoteSessionCloseDisablesSetupState() async {
        let harness = RemoteControlSetupHarness()
        harness.viewModel.remoteControlSetup.enable()

        let response = harness.createdListeners.first?.respond(to: """
        POST /api/session/close HTTP/1.1\r
        Authorization: Bearer token-1\r
        Content-Length: 2\r
        \r
        {}
        """)
        await Task.yield()

        XCTAssertTrue(response?.contains("HTTP/1.1 202 Accepted") == true)
        XCTAssertFalse(harness.viewModel.remoteControlSetup.state.isEnabled)
        XCTAssertNil(harness.viewModel.remoteControlSetup.state.pairingURL)
        XCTAssertEqual(harness.createdListeners.first?.cancelCallCount, 1)
    }
}

@MainActor
private final class RemoteControlSetupHarness {
    let viewModel: SwitcherViewModel
    var createdListeners: [FakeRemoteControlSetupListener] = []
    var nextListenerShouldFailStart = false
    var nextBoundPort: UInt16?

    init() {
        viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.remoteControlSetup.localAddressProvider = { "192.168.1.23" }
        viewModel.remoteControlSetup.tokenProvider = { RemoteControlToken(value: "token-1") }
        viewModel.remoteControlSetup.portProvider = { 41888 }
        viewModel.remoteControlSetup.listenerFactory = makeListener(port:)
    }

    func makeListener(port: UInt16?) throws -> RemoteControlListening {
        let listener = FakeRemoteControlSetupListener(
            requestedPort: port,
            boundPort: nextBoundPort ?? port ?? 41888,
            shouldFailStart: nextListenerShouldFailStart
        )
        nextListenerShouldFailStart = false
        nextBoundPort = nil
        createdListeners.append(listener)
        return listener
    }
}

private final class FakeRemoteControlSetupListener: RemoteControlListening {
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
            throw FakeRemoteControlSetupListenerError.startFailed
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
}

private enum FakeRemoteControlSetupListenerError: Error {
    case startFailed
}
