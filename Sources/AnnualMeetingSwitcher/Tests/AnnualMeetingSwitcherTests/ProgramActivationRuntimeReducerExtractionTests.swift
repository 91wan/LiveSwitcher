import XCTest
@testable import LiveSwitcher

final class ProgramActivationRuntimeReducerExtractionTests: XCTestCase {
    func testProgramActivationRuntimeReducerFileExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: runtimeFile("ProgramActivationRuntimeReducer.swift")))
    }

    func testProgramActivationRuntimeReducerOwnsRequestLogic() throws {
        let source = try reducerSource()

        XCTAssertTrue(source.contains("static func request("))
        XCTAssertTrue(source.contains("state.programActivation.startRequest(id: id)"))
        XCTAssertTrue(source.contains("effects.append(.executeProgramActivation(id: id, plan: plan))"))
    }

    func testProgramActivationRuntimeReducerOwnsCompletionLogic() throws {
        let source = try reducerSource()

        XCTAssertTrue(source.contains("static func complete("))
        XCTAssertTrue(source.contains("state.programActivation.completeRequest(id: id)"))
    }

    func testLiveRuntimeReducerDelegatesProgramActivationRequest() throws {
        let source = try dispatcherSource()
        let body = try caseBody(".operatorRequestedProgramActivation(let id, let plan)", in: source)

        XCTAssertTrue(body.contains("guard LiveRuntimeReducer.isRuntimeOwned(.programActivation, in: bridgeMode) else { return true }"))
        XCTAssertTrue(body.contains("ProgramActivationRuntimeReducer.request("))
    }

    func testLiveRuntimeReducerDelegatesProgramActivationCompletion() throws {
        let source = try dispatcherSource()
        let body = try caseBody(".programActivationCompleted(let id)", in: source)

        XCTAssertTrue(body.contains("guard LiveRuntimeReducer.isRuntimeOwned(.programActivation, in: bridgeMode) else { return true }"))
        XCTAssertTrue(body.contains("ProgramActivationRuntimeReducer.complete(id: id, state: &state)"))
    }

    func testLiveRuntimeReducerDoesNotContainProgramActivationMutationBodies() throws {
        let source = try dispatcherSource()
        let bodies = try [
            caseBody(".operatorRequestedProgramActivation(let id, let plan)", in: source),
            caseBody(".programActivationCompleted(let id)", in: source)
        ].joined(separator: "\n")

        for forbidden in [
            "state.programActivation.startRequest",
            "state.programActivation.completeRequest",
            "effects.append(.executeProgramActivation"
        ] {
            XCTAssertFalse(bodies.contains(forbidden), forbidden)
        }
    }

    private func reducerSource() throws -> String {
        let path = runtimeFile("ProgramActivationRuntimeReducer.swift")
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("ProgramActivationRuntimeReducer.swift is missing")
        }
        return try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/ProgramActivationRuntimeReducer.swift")
    }

    private func dispatcherSource() throws -> String {
        try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/ProgramRuntimeActionDispatcher.swift")
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
