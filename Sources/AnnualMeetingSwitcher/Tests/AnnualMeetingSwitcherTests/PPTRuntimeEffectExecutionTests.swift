import XCTest
@testable import LiveSwitcher

final class PPTRuntimeEffectExecutionTests: XCTestCase {
    func testPPTPortStartDispatchesRuntimeStartedCallback() throws {
        let source = try sourceText("ViewModel+PPTEventTap.swift")
        let body = try functionBody(named: "completePPTEventTapStartFromRuntime", in: source)

        XCTAssertTrue(body.contains(".pptEventTapStarted"))
        XCTAssertFalse(body.contains("isPageInterceptEnabled = true"))
    }

    func testPPTPortStartDispatchesRuntimeFailedCallback() throws {
        let source = try sourceText("ViewModel+PPTEventTap.swift")
        let body = try functionBody(named: "completePPTEventTapStartFailureFromRuntime", in: source)

        XCTAssertTrue(body.contains(".pptEventTapFailed(reason: reason)"))
        XCTAssertTrue(body.contains("syncPPTFacadeFromRuntime()"))
    }

    func testPPTPortStopDispatchesRuntimeStoppedCallback() throws {
        let source = try sourceText("ViewModel+PPTEventTap.swift")
        let body = try functionBody(named: "completePPTEventTapStopFromRuntime", in: source)

        XCTAssertTrue(body.contains(".pptEventTapStopped(reason: reason)"))
        XCTAssertTrue(body.contains("syncPPTFacadeFromRuntime()"))
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
        XCTFail("Could not parse \(name)")
        return ""
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
