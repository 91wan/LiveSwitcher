import XCTest

final class QADocumentationSimplificationTests: XCTestCase {
    func testReleaseCandidateRehearsalRemainsCanonicalTemplateOnly() throws {
        let runbook = try repositorySource("docs/qa/release-candidate-rehearsal.md")

        XCTAssertTrue(runbook.contains("Use this result vocabulary only: PASS, FAIL, BLOCKED, NOT RUN."))
        XCTAssertTrue(runbook.contains("release-acceptance-v0.5.0.md"))
        XCTAssertFalse(runbook.contains("Latest operator smoke note:"))
        XCTAssertFalse(runbook.contains("Stable final automated gates"))
        XCTAssertFalse(runbook.contains("Operator manually tested and approved PR #375/#376"))
        XCTAssertFalse(runbook.contains("| PASS |"))
        XCTAssertFalse(runbook.contains("| NOT RUN | |"))
    }

    func testV050AcceptanceEvidenceIsFrozenOutsideCanonicalTemplate() throws {
        let acceptance = try repositorySource("docs/qa/release-acceptance-v0.5.0.md")

        XCTAssertTrue(acceptance.contains("# LiveSwitcher v0.5.0 Release Acceptance"))
        XCTAssertTrue(acceptance.contains("https://github.com/91wan/LiveSwitcher/releases/tag/v0.5.0"))
        XCTAssertTrue(acceptance.contains("c0e6a046ad4b1892a158e76d5931dd90bb4b8549"))
        XCTAssertTrue(acceptance.contains("LiveSwitcher-macOS-v0.5.0.zip"))
        XCTAssertTrue(acceptance.contains("60-minute soak"))
        XCTAssertTrue(acceptance.contains("Static evidence"))
    }

    func testHardwareRehearsalCloseoutKeepsBehaviorGatesWithoutDocMatrixAssertions() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/HardwareRehearsalCloseoutTests.swift"
        )

        XCTAssertTrue(source.contains("testBGMPauseResumeTwentyCyclesPreservesTimeGenerationAndSingleTimerEffects"))
        XCTAssertTrue(source.contains("testOverlayGeometryCoversCanvasSizesLayerCombinationsCornersAndPriority"))
        XCTAssertTrue(source.contains("testMediaReturnPauseResumeAndEndedContractsStaySeparated"))
        XCTAssertFalse(source.contains("release-candidate-rehearsal.md"))
        XCTAssertFalse(source.contains("operatorAcceptedHumanScenarios"))
        XCTAssertFalse(source.contains("stableAcceptedScenarios"))
    }
}
