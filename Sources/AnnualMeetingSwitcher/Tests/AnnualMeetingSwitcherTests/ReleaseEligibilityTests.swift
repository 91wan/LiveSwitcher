import XCTest

final class ReleaseEligibilityTests: XCTestCase {
    func testReleaseEligibilityDocumentExists() throws {
        XCTAssertTrue(FileManager.default.fileExists(atPath: try releaseEligibilityURL().path))
    }

    func testPatchReleaseAllowedConditionsAreDocumented() throws {
        let document = try releaseEligibilityDocument()
        let requiredPhrases = [
            "P0/P1 crash",
            "external display",
            "Panic",
            "blackout",
            "playback",
            "BGM",
            "checksum",
            "code signing",
            "notarization",
            "user-visible stability fix"
        ]

        for phrase in requiredPhrases {
            XCTAssertTrue(document.localizedStandardContains(phrase), phrase)
        }
    }

    func testPatchReleaseRejectedConditionsAreDocumented() throws {
        let document = try releaseEligibilityDocument()
        let requiredPhrases = [
            "file split",
            "test refactor",
            "documentation-only",
            "complexity gate",
            "source-string tests",
            "allowlist burn-down",
            "internal cleanup"
        ]

        for phrase in requiredPhrases {
            XCTAssertTrue(document.localizedStandardContains(phrase), phrase)
        }
    }

    func testPostStableRefactorsDoNotAutomaticallyPublishPatchReleases() throws {
        let document = try releaseEligibilityDocument()

        XCTAssertTrue(document.localizedStandardContains("post-stable refactor does not require a public release"))
        XCTAssertTrue(document.localizedStandardContains("do not automatically publish a patch release"))
    }

    func testPostStableCleanupDecisionBlocksUnnecessaryV051Release() throws {
        let document = try releaseEligibilityDocument()

        XCTAssertTrue(document.localizedStandardContains("Post-v0.5.0 commits through"))
        XCTAssertTrue(document.localizedStandardContains("internal maintenance only"))
        XCTAssertTrue(document.localizedStandardContains("No v0.5.1 release is required"))
        XCTAssertTrue(document.localizedStandardContains("Patch release remains blocked unless a user-visible production-risk fix or delivery incident fix lands"))
    }

    func testLatestAllowlistBurnDownStillBlocksUnnecessaryV051Release() throws {
        let document = try releaseEligibilityDocument()

        XCTAssertTrue(document.localizedStandardContains("Post-stable allowlist burn-down decision - 2026-06-28"))
        XCTAssertTrue(document.localizedStandardContains("ViewModel runtime identity, projection/page-intercept"))
        XCTAssertTrue(document.localizedStandardContains("root-shell splits removed the remaining production-code allowlist entry"))
        XCTAssertTrue(document.localizedStandardContains("Audio runtime ownership and Persistent runtime load boundary suite splits"))
        XCTAssertTrue(document.localizedStandardContains("allowlist rows: 0"))
        XCTAssertTrue(document.localizedStandardContains("production-code allowlist rows: 0"))
        XCTAssertTrue(document.localizedStandardContains("test-file allowlist rows: 0"))
        XCTAssertTrue(document.localizedStandardContains("source-string allowlist rows: 0"))
        XCTAssertTrue(document.localizedStandardContains("source-string actual total: 0"))
        XCTAssertTrue(document.localizedStandardContains("source-contains allowlist rows are forbidden"))
        XCTAssertTrue(document.localizedStandardContains("No v0.5.1 release is required after this burn-down"))
    }

    func testPhoneLANRemoteStartsV06FeatureStreamWithoutPatchRelease() throws {
        let document = try releaseEligibilityDocument()

        XCTAssertTrue(document.localizedStandardContains("Phone LAN remote control decision - 2026-06-28"))
        XCTAssertTrue(document.localizedStandardContains("v0.6.0 feature stream"))
        XCTAssertTrue(document.localizedStandardContains("does not trigger v0.5.1"))
        XCTAssertTrue(document.localizedStandardContains("do not publish v0.6.0 without hardware rehearsal"))
        XCTAssertTrue(document.localizedStandardContains("No v0.5.1 release is required for the architecture decision"))
    }

    private func releaseEligibilityDocument() throws -> String {
        try String(contentsOf: try releaseEligibilityURL(), encoding: .utf8)
    }

    private func releaseEligibilityURL() throws -> URL {
        try repositoryRoot(filePath: #filePath)
            .appendingPathComponent("docs/qa/release-eligibility.md")
    }
}
