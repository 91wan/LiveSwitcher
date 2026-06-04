import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class ProjectionRuntimeStartFailureTests: XCTestCase {
    func testProjectionStartFailureNoTargetScreenSetsStartFailedNotice() {
        let mutation = reduce(LiveRuntimeState(), .projectionStartFailed(reason: .noTargetScreen))

        XCTAssertFalse(mutation.state.projection.isBroadcasting)
        XCTAssertFalse(mutation.state.projection.hasExternalDisplay)
        XCTAssertEqual(mutation.state.projection.safetyNotice, "未检测到外接屏幕，未开始投射")
    }

    func testProjectionStartFailureNoTargetScreenDoesNotEmitStopProjection() {
        let mutation = reduce(LiveRuntimeState(), .projectionStartFailed(reason: .noTargetScreen))

        XCTAssertFalse(mutation.effects.contains(.stopProjection))
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testProjectionStartFailureDoesNotRecordProjectionLost() {
        let mutation = reduce(LiveRuntimeState(), .projectionStartFailed(reason: .noTargetScreen))

        XCTAssertFalse(mutation.state.support.events.contains { $0.kind == .projectionLost })
        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testProjectionStartFailureRecordsProjectionStartFailedFromViewModel() throws {
        let viewModel = try makeViewModelWithStaleDisplayThatDisappearsBeforeShow()

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionFailClosed })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionStartFailed })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .projectionLost })
    }

    func testProjectionExternalDisplayLostStillRecordsProjectionLost() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: true, hasExternalDisplay: true)

        viewModel.handleExternalDisplayLost()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionFailClosed })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionLost })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .projectionStartFailed })
    }

    func testProjectionStartFailureAndDisplayLostHaveDifferentSafetyNotices() {
        var broadcasting = LiveRuntimeState()
        broadcasting.projection.isBroadcasting = true
        broadcasting.projection.hasExternalDisplay = true

        let startFailed = reduce(LiveRuntimeState(), .projectionStartFailed(reason: .noTargetScreen))
        let displayLost = reduce(broadcasting, .projectionExternalDisplayLost)

        XCTAssertEqual(startFailed.state.projection.safetyNotice, "未检测到外接屏幕，未开始投射")
        XCTAssertEqual(displayLost.state.projection.safetyNotice, "副屏已断开，投射已停止")
    }

    func testShowOutputWindowNoTargetScreenDispatchesProjectionStartFailedNotDisplayLost() throws {
        let viewModel = try makeViewModelWithStaleDisplayThatDisappearsBeforeShow()

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(try showOutputWindowBody().contains(".projectionStartFailed(reason: .noTargetScreen)"))
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionStartFailed })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "projectionExternalDisplayLost" })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .projectionLost })
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: .projectionOwned)
        )
    }

    private func makeViewModelWithStaleDisplayThatDisappearsBeforeShow() throws -> SwitcherViewModel {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        var providerCalls = 0
        viewModel.externalScreenProvider = {
            providerCalls += 1
            return providerCalls == 1 ? screen : nil
        }
        return viewModel
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

    private func showOutputWindowBody() throws -> String {
        let source = try String(
            contentsOf: repositoryRoot()
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift"),
            encoding: .utf8
        )
        guard let start = source.range(of: "func showOutputWindowFromRuntimeProjection")?.lowerBound else {
            XCTFail("Missing showOutputWindowFromRuntimeProjection")
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
        XCTFail("Could not parse showOutputWindowFromRuntimeProjection")
        return ""
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
}
