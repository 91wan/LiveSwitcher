import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class ProjectionRuntimeOwnershipTests: XCTestCase {
    func testHandleBroadcastToggleRefreshesExternalDisplayAvailabilityBeforeDispatch() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { screen }

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
    }

    func testHandleBroadcastToggleUsesFreshAvailabilityForStartDecision() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { nil }
        viewModel.refreshExternalDisplayAvailability()
        viewModel.externalScreenProvider = { screen }

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.startProjection))
    }

    func testProjectionStartFailureDoesNotRecordProjectionToggleTelemetryIfNotBroadcastingChanged() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { nil }
        viewModel.refreshExternalDisplayAvailability()

        viewModel.handleBroadcastToggle()

        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .projectionToggle })
    }

    func testProjectionStartSuccessRecordsProjectionToggleTelemetry() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: false, hasExternalDisplay: true)

        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionToggle }.count, 1)
    }

    func testProjectionStopRecordsProjectionToggleTelemetry() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: true, hasExternalDisplay: true)

        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionToggle }.count, 1)
    }

    func testHandleBroadcastToggleStartsProjectionThroughRuntimePort() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: false, hasExternalDisplay: true)

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.startProjection))
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testHandleBroadcastToggleStopsProjectionThroughRuntimePort() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: true, hasExternalDisplay: true)

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.stopProjection))
        XCTAssertFalse(viewModel.isBroadcasting)
    }

    func testHandleBroadcastToggleStartFailureDoesNotCallProjectionPortStart() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { nil }
        viewModel.refreshExternalDisplayAvailability()

        viewModel.handleBroadcastToggle()

        XCTAssertFalse(viewModel.runtime.recordedEffects.contains(.startProjection))
        XCTAssertFalse(viewModel.isBroadcasting)
    }

    func testHandleBroadcastToggleUpdatesFacadeFromRuntime() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: false, hasExternalDisplay: true)

        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.isBroadcasting, viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertEqual(viewModel.broadcastSafetyNotice, viewModel.runtime.state.projection.safetyNotice)
    }

    func testHandleBroadcastToggleRecordsStartSupportOnce() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: false, hasExternalDisplay: true)

        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionStarted }.count, 1)
    }

    func testHandleBroadcastToggleRecordsStopSupportOnce() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: true, hasExternalDisplay: true)

        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionStopped }.count, 1)
    }

    func testHandleBroadcastToggleRecordsStartFailureSupportOnce() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { nil }
        viewModel.refreshExternalDisplayAvailability()

        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionStartFailed }.count, 1)
        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionFailClosed }.count, 1)
    }

    func testRepeatedStartFailureDoesNotDuplicateProjectionLost() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { nil }
        viewModel.refreshExternalDisplayAvailability()

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .projectionLost })
    }

    func testHandleBroadcastToggleUsesRuntimeProjectionState() throws {
        let body = try functionBody(named: "handleBroadcastToggle")

        XCTAssertTrue(body.contains("let oldProjection = runtime.state.projection"))
        XCTAssertTrue(body.contains("refreshExternalDisplayAvailability()"))
        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.operatorToggledProjection)"))
        XCTAssertTrue(body.contains("syncProjectionFacadeFromRuntime()"))
        XCTAssertTrue(body.contains("recordProjectionSupportAfterRuntimeToggle"))
    }

    func testHandleBroadcastToggleDoesNotDirectlyToggleIsBroadcasting() throws {
        let body = try functionBody(named: "handleBroadcastToggle")

        XCTAssertFalse(body.contains("isBroadcasting.toggle()"))
        XCTAssertFalse(body.contains("isBroadcasting = true"))
        XCTAssertFalse(body.contains("isBroadcasting = false"))
    }

    func testHandleBroadcastToggleDoesNotDirectlyCallShowOutputWindow() throws {
        let body = try functionBody(named: "handleBroadcastToggle")

        XCTAssertFalse(body.contains("showOutputWindow()"))
    }

    func testHandleBroadcastToggleDoesNotDirectlyCallHideOutputWindow() throws {
        let body = try functionBody(named: "handleBroadcastToggle")

        XCTAssertFalse(body.contains("hideOutputWindow()"))
    }

    func testProjectionStartRecordsSupportFromViewModelAfterRuntimeTransition() throws {
        let body = try projectionOutputSource()

        XCTAssertTrue(body.contains("recordProjectionSupportAfterRuntimeToggle"))
        XCTAssertTrue(body.contains(".projectionStarted"))
        XCTAssertTrue(body.contains(".projectionToggle"))
    }

    func testProjectionFailureRecordsSupportFromViewModelAfterRuntimeTransition() throws {
        let body = try projectionOutputSource()

        XCTAssertTrue(body.contains(".projectionFailClosed"))
        XCTAssertTrue(body.contains(".projectionStartFailed"))
    }

    func testProjectionStopRecordsSupportFromViewModelAfterRuntimeTransition() throws {
        let body = try projectionOutputSource()

        XCTAssertTrue(body.contains(".projectionStopped"))
    }

    func testProjectionSupportEventsAreNotDuplicated() throws {
        let body = try functionBody(named: "recordProjectionSupportAfterRuntimeToggle")

        XCTAssertLessThanOrEqual(body.occurrenceCount(of: ".projectionStarted"), 1)
        XCTAssertLessThanOrEqual(body.occurrenceCount(of: ".projectionStopped"), 1)
        XCTAssertLessThanOrEqual(body.occurrenceCount(of: ".projectionStartFailed"), 1)
    }

    private func functionBody(named name: String) throws -> String {
        let source = try projectionOutputSource()
        guard let start = source.range(of: "func \(name)")?.lowerBound else {
            XCTFail("Missing function \(name)")
            return ""
        }
        var index = start
        var depth = 0
        var hasOpened = false
        while index < source.endIndex {
            let character = source[index]
            if character == "{" {
                depth += 1
                hasOpened = true
            } else if character == "}" {
                depth -= 1
                if hasOpened && depth == 0 {
                    return String(source[start...index])
                }
            }
            index = source.index(after: index)
        }
        XCTFail("Could not parse function \(name)")
        return ""
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func projectionOutputSource() throws -> String {
        try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProjectionOutput.swift")
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }

    private func makeProjectionOwnedViewModel(
        isBroadcasting: Bool,
        hasExternalDisplay: Bool
    ) throws -> SwitcherViewModel {
        let screen = NSScreen.main ?? NSScreen.screens.first
        if hasExternalDisplay, screen == nil {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = isBroadcasting
        state.projection.hasExternalDisplay = hasExternalDisplay
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .projectionOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.isBroadcasting = isBroadcasting
        viewModel.externalScreenProvider = { hasExternalDisplay ? screen : nil }
        viewModel.refreshExternalDisplayAvailability()
        return viewModel
    }
}

private extension String {
    func occurrenceCount(of needle: String) -> Int {
        components(separatedBy: needle).count - 1
    }
}
