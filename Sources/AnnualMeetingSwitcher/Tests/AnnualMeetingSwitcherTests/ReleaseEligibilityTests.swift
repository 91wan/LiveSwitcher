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

    private func releaseEligibilityDocument() throws -> String {
        try String(contentsOf: try releaseEligibilityURL(), encoding: .utf8)
    }

    private func releaseEligibilityURL() throws -> URL {
        try repositoryRoot(filePath: #filePath)
            .appendingPathComponent("docs/qa/release-eligibility.md")
    }
}
