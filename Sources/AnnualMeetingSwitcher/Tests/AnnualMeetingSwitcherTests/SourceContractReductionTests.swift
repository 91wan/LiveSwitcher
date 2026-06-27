import XCTest

final class SourceContractReductionTests: XCTestCase {
    func testTargetedSourceContainsCountsContinueDropping() throws {
        XCTAssertLessThanOrEqual(
            try sourceContainsCallCount(in: "MediaRuntimeReducerExtractionTests.swift"),
            0
        )
        XCTAssertLessThanOrEqual(
            try sourceContainsCallCount(in: "ViewModelPersistenceFacadeTests.swift"),
            27
        )
        XCTAssertLessThanOrEqual(
            try sourceContainsCallCount(in: "LiveModeLayoutTests.swift"),
            44
        )
    }

    private func sourceContainsCallCount(in testFile: String) throws -> Int {
        let text = try String(
            contentsOf: repositoryRoot(filePath: #filePath)
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests")
                .appendingPathComponent(testFile),
            encoding: .utf8
        )
        let sourceContainsCall = "source" + ".contains"
        return text.components(separatedBy: sourceContainsCall).count - 1
    }
}
