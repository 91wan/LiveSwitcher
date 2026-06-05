import XCTest
@testable import LiveSwitcher

final class SupportRuntimeLegacyBoundaryTests: XCTestCase {
    func testRecordSupportEventDoesNotCallLegacyFacadeSyncInProductionPath() throws {
        let body = try viewModelFunctionBody(named: "func recordSupportEvent")

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.supportEventRecorded(event))"))
        XCTAssertTrue(body.contains("syncSupportFacadeFromRuntime()"))
        XCTAssertFalse(body.contains("syncLegacySupportFacadeFromRuntime()"))
    }

    func testHandleAppleScriptFailureDoesNotCallLegacyFacadeSyncInProductionPath() throws {
        let body = try viewModelFunctionBody(named: "func handleAppleScriptFailure")

        XCTAssertTrue(body.contains("recordSupportEvent(kind: .appleScriptFailed"))
        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.automationFailed"))
        XCTAssertTrue(body.contains("syncSupportFacadeFromRuntime()"))
        XCTAssertFalse(body.contains("syncLegacySupportFacadeFromRuntime()"))
    }

    func testLegacySupportFacadeSyncHasBeenRemoved() throws {
        let sources = try [
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacadeSync.swift"
        ].map(sourceText).joined(separator: "\n")

        XCTAssertFalse(sources.contains("syncLegacySupportFacadeFromRuntime"))
    }

    func testSupportEventsFacadeIsNotPublic() throws {
        let sources = try [
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacadeSync.swift"
        ].map(sourceText).joined(separator: "\n")

        XCTAssertTrue(sources.contains("var supportEvents"))
        XCTAssertFalse(sources.contains("public var supportEvents"))
        XCTAssertFalse(sources.contains("open var supportEvents"))
    }

    private func viewModelFunctionBody(named marker: String) throws -> String {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        guard let markerRange = source.range(of: marker) else {
            XCTFail("Missing \(marker)")
            return ""
        }
        let suffix = source[markerRange.lowerBound...]
        guard let nextMark = suffix.range(of: "\n    // MARK:", options: [], range: suffix.index(after: suffix.startIndex)..<suffix.endIndex) else {
            return String(suffix)
        }
        return String(suffix[..<nextMark.lowerBound])
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate)
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
