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

    func testReleaseHygieneDocumentsV05ReproducibilityTrustModel() throws {
        let hygiene = try repositorySource("docs/qa/release-hygiene-v0.5.0.md")

        XCTAssertTrue(hygiene.contains("## Release reproducibility limits"))
        XCTAssertTrue(hygiene.contains("tag/main equality"))
        XCTAssertTrue(hygiene.contains("CI workflow"))
        XCTAssertTrue(hygiene.contains("release asset checksum"))
        XCTAssertTrue(hygiene.contains("extracted app verification"))
        XCTAssertTrue(hygiene.contains("does not promise byte-for-byte local rebuild reproducibility"))
        XCTAssertTrue(hygiene.contains("build path"))
        XCTAssertTrue(hygiene.contains("timestamps"))
        XCTAssertTrue(hygiene.contains("resource ordering"))
        XCTAssertTrue(hygiene.contains("signing metadata"))
        XCTAssertTrue(hygiene.contains("must not be treated as compromised by itself"))
        XCTAssertTrue(hygiene.contains("published `.sha256`"))
    }

    func testReleaseHygieneRecordsPostStableNoReleaseDecision() throws {
        let hygiene = try repositorySource("docs/qa/release-hygiene-v0.5.0.md")

        XCTAssertTrue(hygiene.contains("Post-v0.5.0 commits through"))
        XCTAssertTrue(hygiene.contains("internal maintenance only"))
        XCTAssertTrue(hygiene.contains("No v0.5.1 release is required"))
        XCTAssertTrue(hygiene.contains("Patch release remains blocked unless a user-visible production-risk fix or delivery incident fix lands"))
    }

    func testReleaseCandidateTemplateRecordsReproducibilityEvidenceWithoutClaimingByteIdentity() throws {
        let runbook = try repositorySource("docs/qa/release-candidate-rehearsal.md")

        XCTAssertTrue(runbook.contains("## Release Reproducibility Note"))
        XCTAssertTrue(runbook.contains("Do not require byte-for-byte local rebuild identity"))
        XCTAssertTrue(runbook.contains("release asset checksum"))
        XCTAssertTrue(runbook.contains("build path"))
        XCTAssertTrue(runbook.contains("timestamps"))
        XCTAssertTrue(runbook.contains("resource ordering"))
        XCTAssertTrue(runbook.contains("signing metadata"))
        XCTAssertTrue(runbook.contains("does not by itself prove compromise"))
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
