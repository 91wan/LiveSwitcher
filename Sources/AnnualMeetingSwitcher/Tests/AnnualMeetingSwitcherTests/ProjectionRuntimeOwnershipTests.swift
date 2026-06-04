import XCTest
@testable import LiveSwitcher

final class ProjectionRuntimeOwnershipTests: XCTestCase {
    func testHandleBroadcastToggleUsesRuntimeProjectionState() throws {
        let body = try functionBody(named: "handleBroadcastToggle")

        XCTAssertTrue(body.contains("let oldProjection = runtime.state.projection"))
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
        let body = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertTrue(body.contains("recordProjectionSupportAfterRuntimeToggle"))
        XCTAssertTrue(body.contains(".projectionStarted"))
        XCTAssertTrue(body.contains(".projectionToggle"))
    }

    func testProjectionFailureRecordsSupportFromViewModelAfterRuntimeTransition() throws {
        let body = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertTrue(body.contains(".projectionFailClosed"))
        XCTAssertTrue(body.contains(".projectionStartFailed"))
    }

    func testProjectionStopRecordsSupportFromViewModelAfterRuntimeTransition() throws {
        let body = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertTrue(body.contains(".projectionStopped"))
    }

    func testProjectionSupportEventsAreNotDuplicated() throws {
        let body = try functionBody(named: "recordProjectionSupportAfterRuntimeToggle")

        XCTAssertLessThanOrEqual(body.occurrenceCount(of: ".projectionStarted"), 1)
        XCTAssertLessThanOrEqual(body.occurrenceCount(of: ".projectionStopped"), 1)
        XCTAssertLessThanOrEqual(body.occurrenceCount(of: ".projectionStartFailed"), 1)
    }

    private func functionBody(named name: String) throws -> String {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
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

private extension String {
    func occurrenceCount(of needle: String) -> Int {
        components(separatedBy: needle).count - 1
    }
}
