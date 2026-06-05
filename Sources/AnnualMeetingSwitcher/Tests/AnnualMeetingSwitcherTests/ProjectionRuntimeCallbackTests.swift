import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class ProjectionRuntimeCallbackTests: XCTestCase {
    func testExternalDisplayLostDispatchesRuntimeAction() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: true, hasExternalDisplay: true)

        viewModel.handleExternalDisplayLost()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "projectionExternalDisplayLost" })
    }

    func testExternalDisplayLostSyncsFacadeFromRuntime() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: true, hasExternalDisplay: true)

        viewModel.handleExternalDisplayLost()

        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "副屏已断开，投射已停止")
    }

    func testExternalDisplayLostDoesNotDirectlyMutateBroadcasting() throws {
        let body = try functionBody(named: "handleExternalDisplayLost")

        XCTAssertFalse(body.contains("isBroadcasting = false"))
        XCTAssertFalse(body.contains("broadcastSafetyNotice ="))
    }

    func testExternalDisplayLostRecordsSupportOnce() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: true, hasExternalDisplay: true)

        viewModel.handleExternalDisplayLost()
        viewModel.handleExternalDisplayLost()

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionLost }.count, 1)
        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionFailClosed }.count, 1)
    }

    func testExternalDisplayLostIsIdempotent() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: true, hasExternalDisplay: true)

        viewModel.handleExternalDisplayLost()
        let firstLogCount = viewModel.runtime.actionLog.count
        viewModel.handleExternalDisplayLost()

        XCTAssertEqual(viewModel.runtime.actionLog.count, firstLogCount)
    }

    func testExternalDisplayAvailableUpdatesRuntimeAvailability() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: false, hasExternalDisplay: false)

        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        viewModel.externalScreenProvider = { screen }
        viewModel.refreshExternalDisplayAvailability()
        viewModel.dispatchRuntimeFacadeAction(.projectionExternalDisplayAvailable)

        XCTAssertTrue(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertFalse(viewModel.runtime.state.projection.isBroadcasting)
    }

    func testExternalDisplayUnavailableDoesNotAutoStartProjection() throws {
        let viewModel = try makeProjectionOwnedViewModel(isBroadcasting: false, hasExternalDisplay: true)

        viewModel.externalScreenProvider = { nil }
        viewModel.refreshExternalDisplayAvailability()
        viewModel.dispatchRuntimeFacadeAction(.projectionExternalDisplayUnavailable)

        XCTAssertFalse(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertFalse(viewModel.runtime.state.projection.isBroadcasting)
    }

    func testOutputWindowUnavailableCallbackDispatchesRuntimeProjectionLost() throws {
        let viewModel = try makeProductionViewModelWithDisplay()
        let outputSpy = OutputWindowControllerSpy()

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.handleBroadcastToggle()
        outputSpy.onExternalDisplayUnavailable?()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "projectionExternalDisplayLost" })
        XCTAssertFalse(viewModel.isBroadcasting)
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

    private func makeProductionViewModelWithDisplay() throws -> SwitcherViewModel {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { screen }
        return viewModel
    }

    private func functionBody(named name: String) throws -> String {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProjectionOutput.swift")
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

private final class OutputWindowControllerSpy: OutputWindowControlling {
    var onExternalDisplayUnavailable: (() -> Void)?
    private(set) var mountCount = 0
    private(set) var showCount = 0
    private(set) var hideCount = 0

    func mountAnyView(rootView: AnyView) {
        mountCount += 1
    }

    func show(on screen: NSScreen?) {
        showCount += 1
    }

    func hide() {
        hideCount += 1
    }
}
