import XCTest
@testable import LiveSwitcher

final class AutomationCommandRuntimeBoundaryTests: XCTestCase {
    func testRunAutomationScriptDispatchesRuntimeAction() throws {
        let body = try runAutomationScriptBody()

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.automationScriptRequested(script: source, action: action))"))
    }

    func testRunAutomationScriptStillDispatchesRuntimeAction() throws {
        try testRunAutomationScriptDispatchesRuntimeAction()
    }

    func testRunAutomationScriptDoesNotCallAppleScriptRunnerDirectly() throws {
        let body = try runAutomationScriptBody()

        XCTAssertFalse(body.contains("AppleScriptRunner.run"))
    }

    func testKeynoteNextSlideUsesRuntimeAutomationCommand() throws {
        XCTAssertTrue(try functionBody("keynoteNextSlide").contains("runAutomationScript("))
    }

    func testKeynotePreviousSlideUsesRuntimeAutomationCommand() throws {
        XCTAssertTrue(try functionBody("keynotePreviousSlide").contains("runAutomationScript("))
    }

    func testStopDeckPresentationUsesRuntimeAutomationCommand() throws {
        XCTAssertTrue(try functionBody("stopDeckPresentation").contains("runAutomationScript("))
    }

    func testOpenAndPresentKeynoteUsesRuntimeAutomationCommand() throws {
        XCTAssertTrue(try functionBody("openAndPresentKeynote").contains("runAutomationScript("))
    }

    func testPresentFrontKeynoteDocumentUsesRuntimeAutomationCommand() throws {
        XCTAssertTrue(try functionBody("presentFrontKeynoteDocument").contains("runAutomationScript("))
    }

    func testEveryRunAutomationScriptCallSiteUsesRuntimeCommand() throws {
        let source = try presentationAutomationSource()
        let callSites = source.components(separatedBy: "runAutomationScript(").count - 1

        XCTAssertGreaterThanOrEqual(callSites, 6)
        XCTAssertTrue(try runAutomationScriptBody().contains(".automationScriptRequested(script: source, action: action)"))
    }

    func testOpenPPTXWPSFallbackBranchRemainsViewModelOwned() throws {
        let body = try functionBody("openPPTXWithKeynote")

        XCTAssertTrue(body.contains("AppleScriptRunner.run(wpsScript"))
        XCTAssertFalse(body.contains(".automationScriptRequested"))
    }

    func testScanKeynoteWindowNamesRemainsViewModelOwned() throws {
        let body = try functionBody("scanKeynoteWindowNames")

        XCTAssertTrue(body.contains("AppleScriptRunner.run(script, action: \"keynote.scan.windows\")"))
        XCTAssertFalse(body.contains(".automationScriptRequested"))
    }

    func testScanOpenKeynoteFilesRemainsViewModelOwned() throws {
        let body = try functionBody("scanOpenKeynoteFiles")

        XCTAssertTrue(body.contains("keynoteController.scanOpenKeynoteFiles()"))
        XCTAssertFalse(body.contains(".automationScriptRequested"))
    }

    func testKeynoteControllerQueriesRemainForbiddenForThisMigration() throws {
        let controller = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Engines/KeynoteController.swift")

        XCTAssertTrue(controller.contains("func scanOpenKeynoteFiles"))
        XCTAssertTrue(controller.contains("func scanKeynoteWindowNames"))
        XCTAssertFalse(controller.contains(".automationScriptRequested"))
    }

    func testNoResultReturningQueryDispatchesAutomationScriptRequested() throws {
        for name in ["scanKeynoteWindowNames", "scanOpenKeynoteFiles", "openPPTXWithKeynote"] {
            XCTAssertFalse(try functionBody(name).contains(".automationScriptRequested"), name)
        }
    }

    func testRuntimeDocsStateQueryMigrationRequiresCommandIDs() throws {
        let docs = try sourceText("docs/architecture/runtime-ownership.md")
        let normalizedDocs = docs.components(separatedBy: .whitespacesAndNewlines).joined(separator: " ")

        XCTAssertTrue(normalizedDocs.localizedStandardContains("query migration must introduce explicit command/query IDs"))
        XCTAssertTrue(normalizedDocs.localizedStandardContains("callback result actions"))
    }

    func testResultReturningKeynoteScanRemainsViewModelOwnedAndDocumented() throws {
        let scanWindows = try functionBody("scanKeynoteWindowNames")
        let docs = try sourceText("docs/architecture/runtime-ownership.md")

        XCTAssertTrue(scanWindows.contains("AppleScriptRunner.run"))
        XCTAssertTrue(docs.localizedStandardContains("Keynote/WPS result-returning AppleScript queries"))
    }

    func testWPSFallbackOpenFlowRemainsViewModelOwnedAndDocumented() throws {
        let openPPTX = try functionBody("openPPTXWithKeynote")
        let docs = try sourceText("docs/architecture/live-mode-simplicity-rules.md")

        XCTAssertTrue(openPPTX.contains("AppleScriptRunner.run(wpsScript"))
        XCTAssertTrue(openPPTX.contains("openWithWPSOffice"))
        XCTAssertTrue(docs.localizedStandardContains("WPS fallback branching"))
    }

    private func runAutomationScriptBody() throws -> String {
        try functionBody("runAutomationScript")
    }

    private func functionBody(_ name: String) throws -> String {
        let source = try presentationAutomationSource()
        return try XCTUnwrap(source.functionBody(named: name))
    }

    private func presentationAutomationSource() throws -> String {
        try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift")
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
    func functionBody(named functionName: String) -> String? {
        guard let nameRange = range(of: "func \(functionName)") else { return nil }
        guard let openingBrace = self[nameRange.lowerBound...].firstIndex(of: "{") else { return nil }
        return balancedBody(startingAt: openingBrace)
    }

    func balancedBody(startingAt openingBrace: String.Index) -> String? {
        var depth = 0
        var index = openingBrace
        while index < endIndex {
            if self[index] == "{" {
                depth += 1
            } else if self[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}
