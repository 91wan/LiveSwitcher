import XCTest

final class ProjectionRuntimeRawSideEffectBoundaryTests: XCTestCase {
    func testNoPublicShowOutputWindowBypassRemains() throws {
        let source = try viewModelSource()

        XCTAssertNil(source.range(of: "\n    func showOutputWindow()"))
    }

    func testNoPublicHideOutputWindowBypassRemains() throws {
        let source = try viewModelSource()

        XCTAssertNil(source.range(of: "\n    func hideOutputWindow()"))
    }

    func testOutputWindowSideEffectsOnlyInsideProjectionPortHandlers() throws {
        let source = try viewModelSource()
        let toggleBody = try functionBody(named: "handleBroadcastToggle", in: source)
        let lostBody = try functionBody(named: "handleExternalDisplayLost", in: source)
        let startBody = try functionBody(named: "showOutputWindowFromRuntimeProjection", in: source)
        let stopBody = try functionBody(named: "hideOutputWindowFromRuntimeProjection", in: source)

        XCTAssertFalse(toggleBody.contains("outputWindowController"))
        XCTAssertFalse(lostBody.contains("outputWindowController"))
        XCTAssertTrue(startBody.contains("outputWindowController"))
        XCTAssertTrue(stopBody.contains("outputWindowController"))
    }

    func testHandleBroadcastToggleDoesNotCallRawOutputSideEffects() throws {
        let body = try functionBody(named: "handleBroadcastToggle", in: try viewModelSource())

        XCTAssertFalse(body.contains("showOutputWindow("))
        XCTAssertFalse(body.contains("hideOutputWindow("))
        XCTAssertFalse(body.contains("showOutputWindowFromRuntimeProjection("))
        XCTAssertFalse(body.contains("hideOutputWindowFromRuntimeProjection("))
    }

    func testHandleExternalDisplayLostDoesNotCallRawOutputSideEffects() throws {
        let body = try functionBody(named: "handleExternalDisplayLost", in: try viewModelSource())

        XCTAssertFalse(body.contains("showOutputWindow("))
        XCTAssertFalse(body.contains("hideOutputWindow("))
        XCTAssertFalse(body.contains("showOutputWindowFromRuntimeProjection("))
        XCTAssertFalse(body.contains("hideOutputWindowFromRuntimeProjection("))
    }

    private func viewModelSource() throws -> String {
        try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
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
