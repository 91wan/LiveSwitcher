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

    func testLegacySupportFacadeSyncRemainsGuardedForNonSupportOwnedCompatibility() throws {
        let body = try viewModelFunctionBody(named: "private func syncLegacySupportFacadeFromRuntime")

        XCTAssertTrue(body.contains("guard !runtime.bridgeMode.owns(.support) else { return }"))
        XCTAssertTrue(body.contains("supportEvents = runtime.state.support.events"))
    }

    func testSupportEventsFacadeIsPrivateSet() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertTrue(source.contains("private(set) var supportEvents"))
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
