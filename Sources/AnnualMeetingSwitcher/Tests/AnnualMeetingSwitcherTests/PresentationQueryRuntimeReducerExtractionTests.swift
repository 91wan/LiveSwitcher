import XCTest
@testable import LiveSwitcher

final class PresentationQueryRuntimeReducerExtractionTests: XCTestCase {
    func testPresentationQueryRuntimeReducerFileExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: runtimeFile("PresentationQueryRuntimeReducer.swift")))
    }

    func testPresentationQueryRuntimeReducerOwnsRequestLogic() throws {
        let source = try reducerSource()

        XCTAssertTrue(source.contains("static func request("))
        XCTAssertTrue(source.contains("state.presentationQuery.activeRequestID = id"))
        XCTAssertTrue(source.contains("state.presentationQuery.latestCompletedRequestID = nil"))
        XCTAssertTrue(source.contains("state.presentationQuery.latestResult = nil"))
        XCTAssertTrue(source.contains("state.presentationQuery.latestFailure = nil"))
        XCTAssertTrue(source.contains("effects.append(.scanPresentationQuery(id: id))"))
    }

    func testPresentationQueryRuntimeReducerOwnsCompletionLogic() throws {
        let source = try reducerSource()

        XCTAssertTrue(source.contains("static func complete("))
        XCTAssertTrue(source.contains("guard state.presentationQuery.activeRequestID == id else { return }"))
        XCTAssertTrue(source.contains("state.presentationQuery.activeRequestID = nil"))
        XCTAssertTrue(source.contains("state.presentationQuery.latestCompletedRequestID = id"))
        XCTAssertTrue(source.contains("state.presentationQuery.latestResult = result"))
        XCTAssertTrue(source.contains("state.presentationQuery.latestFailure = nil"))
    }

    func testPresentationQueryRuntimeReducerOwnsFailureLogic() throws {
        let source = try reducerSource()

        XCTAssertTrue(source.contains("static func fail("))
        XCTAssertTrue(source.contains("guard state.presentationQuery.activeRequestID == id else { return }"))
        XCTAssertTrue(source.contains("state.presentationQuery.latestCompletedRequestID = nil"))
        XCTAssertTrue(source.contains("state.presentationQuery.latestResult = nil"))
        XCTAssertTrue(source.contains("state.presentationQuery.latestFailure = PresentationQueryFailure("))
    }

    func testPresentationQueryRuntimeReducerOwnsConsumeLogic() throws {
        let source = try reducerSource()

        XCTAssertTrue(source.contains("static func consumeResult("))
        XCTAssertTrue(source.contains("state.presentationQuery.markConsumed(id)"))
    }

    func testLiveRuntimeReducerDelegatesPresentationQueryRequest() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")
        let body = try caseBody(".operatorRequestedPresentationQuery(let id)", in: source)

        XCTAssertTrue(body.contains("guard isRuntimeOwned(.presentationQuery, in: bridgeMode) else { break }"))
        XCTAssertTrue(body.contains("PresentationQueryRuntimeReducer.request("))
    }

    func testLiveRuntimeReducerDelegatesPresentationQueryCompleted() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")
        let body = try caseBody(".presentationQueryCompleted(let id, let result)", in: source)

        XCTAssertTrue(body.contains("guard isRuntimeOwned(.presentationQuery, in: bridgeMode) else { break }"))
        XCTAssertTrue(body.contains("PresentationQueryRuntimeReducer.complete(id: id, result: result, state: &state)"))
    }

    func testLiveRuntimeReducerDelegatesPresentationQueryFailed() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")
        let body = try caseBody(".presentationQueryFailed(let id, let action, let sanitizedMessage)", in: source)

        XCTAssertTrue(body.contains("guard isRuntimeOwned(.presentationQuery, in: bridgeMode) else { break }"))
        XCTAssertTrue(body.contains("PresentationQueryRuntimeReducer.fail("))
    }

    func testLiveRuntimeReducerDelegatesPresentationQueryConsumed() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")
        let body = try caseBody(".presentationQueryResultConsumed(let id)", in: source)

        XCTAssertTrue(body.contains("guard isRuntimeOwned(.presentationQuery, in: bridgeMode) else { break }"))
        XCTAssertTrue(body.contains("PresentationQueryRuntimeReducer.consumeResult(id: id, state: &state)"))
    }

    func testLiveRuntimeReducerDoesNotContainPresentationQueryMutationBodies() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")
        let bodies = try [
            caseBody(".operatorRequestedPresentationQuery(let id)", in: source),
            caseBody(".presentationQueryCompleted(let id, let result)", in: source),
            caseBody(".presentationQueryFailed(let id, let action, let sanitizedMessage)", in: source),
            caseBody(".presentationQueryResultConsumed(let id)", in: source)
        ].joined(separator: "\n")

        for forbidden in [
            "state.presentationQuery.activeRequestID =",
            "state.presentationQuery.latestCompletedRequestID =",
            "state.presentationQuery.latestResult =",
            "state.presentationQuery.latestFailure =",
            "state.presentationQuery.markConsumed",
            "PresentationQueryFailure(",
            "effects.append(.scanPresentationQuery"
        ] {
            XCTAssertFalse(bodies.contains(forbidden), forbidden)
        }
    }

    private func reducerSource() throws -> String {
        guard FileManager.default.fileExists(atPath: runtimeFile("PresentationQueryRuntimeReducer.swift")) else {
            throw XCTSkip("PresentationQueryRuntimeReducer.swift is missing")
        }
        return try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/PresentationQueryRuntimeReducer.swift")
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
