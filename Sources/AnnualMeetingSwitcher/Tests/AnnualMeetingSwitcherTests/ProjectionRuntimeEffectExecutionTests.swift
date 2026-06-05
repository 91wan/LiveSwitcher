import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class ProjectionRuntimeEffectExecutionTests: XCTestCase {
    func testStartProjectionEffectCallsProjectionPortStart() {
        let projection = ProjectionRuntimeEffectPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, projection: projection)

        runner.run([.startProjection], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(projection.calls, ["start"])
    }

    func testStopProjectionEffectCallsProjectionPortStop() {
        let projection = ProjectionRuntimeEffectPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, projection: projection)

        runner.run([.stopProjection], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(projection.calls, ["stop"])
    }

    func testShowOutputWindowEffectCallsProjectionPortShow() {
        let projection = ProjectionRuntimeEffectPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, projection: projection)

        runner.run([.showOutputWindow], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(projection.calls, ["show"])
    }

    func testHideOutputWindowEffectCallsProjectionPortHide() {
        let projection = ProjectionRuntimeEffectPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, projection: projection)

        runner.run([.hideOutputWindow], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(projection.calls, ["hide"])
    }

    func testProjectionPortStartDoesNotMutateViewModelBroadcastingDirectly() throws {
        let source = try projectionOutputSource()
        let body = try functionBody(named: "showOutputWindowFromRuntimeProjection", in: source)

        XCTAssertFalse(body.contains("isBroadcasting ="))
        XCTAssertFalse(body.contains("broadcastSafetyNotice ="))
        XCTAssertFalse(body.contains("recordSupportEvent("))
    }

    func testProjectionPortStartWithoutScreenDispatchesProjectionStartFailed() throws {
        let source = try projectionOutputSource()
        let body = try functionBody(named: "showOutputWindowFromRuntimeProjection", in: source)

        XCTAssertTrue(body.contains(".projectionStartFailed(reason: .noTargetScreen)"))
        XCTAssertFalse(body.contains(".projectionExternalDisplayLost"))
    }

    func testOutputWindowControllerIsOnlyTouchedInsideProjectionPortHandlers() throws {
        let source = try projectionOutputSource()

        XCTAssertTrue(source.contains("showOutputWindowFromRuntimeProjection"))
        XCTAssertTrue(source.contains("hideOutputWindowFromRuntimeProjection"))
        XCTAssertFalse(try functionBody(named: "handleBroadcastToggle", in: source).contains("outputWindowController"))
        XCTAssertFalse(try functionBody(named: "handleExternalDisplayLost", in: source).contains("outputWindowController"))
    }

    func testProjectionPortStartMountsOutputViewOnlyOnce() throws {
        let (viewModel, outputSpy) = try makeViewModelWithOutputSpy()

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertEqual(outputSpy.mountCount, 1)
    }

    func testProjectionPortStartCanShowExistingOutputWindowAgain() throws {
        let (viewModel, outputSpy) = try makeViewModelWithOutputSpy()

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertEqual(outputSpy.showCount, 2)
    }

    func testProjectionPortStopCanHideWithoutDestroyingController() throws {
        let (viewModel, outputSpy) = try makeViewModelWithOutputSpy()

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertEqual(outputSpy.hideCount, 1)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 2)
    }

    private func functionBody(named name: String, in source: String) throws -> String {
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

    private func makeViewModelWithOutputSpy() throws -> (SwitcherViewModel, ProjectionEffectOutputWindowControllerSpy) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let outputSpy = ProjectionEffectOutputWindowControllerSpy()
        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.externalScreenProvider = { screen }
        return (viewModel, outputSpy)
    }
}

private final class ProjectionRuntimeEffectPortSpy: ProjectionPort {
    var calls: [String] = []
    var hasExternalDisplay = true

    func start() { calls.append("start") }
    func stop() { calls.append("stop") }
    func show() { calls.append("show") }
    func hide() { calls.append("hide") }
}

private final class ProjectionEffectOutputWindowControllerSpy: OutputWindowControlling {
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
