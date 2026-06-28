import XCTest
@testable import LiveSwitcher

final class AutomationCommandRuntimeReducerExtractionTests: XCTestCase {
    func testAutomationCommandRuntimeReducerFileExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: runtimeFile("AutomationCommandRuntimeReducer.swift")))
    }

    func testAutomationCommandRuntimeReducerOwnsScriptRequestLogic() throws {
        let source = try reducerSource()

        XCTAssertTrue(source.contains("static func requestScript("))
        XCTAssertTrue(source.contains("effects.append(.runAppleScript(script: script, action: action))"))
    }

    func testLiveRuntimeReducerDelegatesAutomationScriptRequested() throws {
        let source = try dispatcherSource()
        let body = try caseBody(".automationScriptRequested(let script, let action)", in: source)

        XCTAssertTrue(body.contains("guard LiveRuntimeReducer.isRuntimeOwned(.automationCommand, in: bridgeMode) else { return true }"))
        XCTAssertTrue(body.contains("AutomationCommandRuntimeReducer.requestScript("))
    }

    func testLiveRuntimeReducerDoesNotAppendRunAppleScriptDirectly() throws {
        let source = try dispatcherSource()
        let body = try caseBody(".automationScriptRequested(let script, let action)", in: source)

        XCTAssertFalse(body.contains("effects.append(.runAppleScript"), body)
    }

    private func reducerSource() throws -> String {
        let path = runtimeFile("AutomationCommandRuntimeReducer.swift")
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("AutomationCommandRuntimeReducer.swift is missing")
        }
        return try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/AutomationCommandRuntimeReducer.swift")
    }

    private func dispatcherSource() throws -> String {
        try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/AutomationRuntimeActionDispatcher.swift")
    }

    private func runtimeFile(_ name: String) -> String {
        let tests = URL(fileURLWithPath: #filePath)
        return tests
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Runtime/\(name)")
            .path
    }

    private func caseBody(_ casePattern: String, in source: String) throws -> String {
        guard let range = source.range(of: "case \(casePattern):") else {
            throw NSError(domain: "Missing case \(casePattern)", code: 1)
        }
        let nextCase = source[range.upperBound...].range(of: "\n        case ")
        let end = nextCase?.lowerBound ?? source.endIndex
        return String(source[range.lowerBound..<end])
    }
}
