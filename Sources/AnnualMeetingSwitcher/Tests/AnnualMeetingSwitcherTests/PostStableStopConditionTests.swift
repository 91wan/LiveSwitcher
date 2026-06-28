import XCTest

final class PostStableStopConditionTests: XCTestCase {
    func testStopConditionDocumentDefinesExitCriteria() throws {
        let document = try stopConditionDocument()

        XCTAssertTrue(document.localizedStandardContains("Post-Stable Stop Condition"))
        XCTAssertTrue(document.localizedStandardContains("Once the complexity allowlist is empty or contains only accepted exceptions"))
        XCTAssertTrue(document.localizedStandardContains("Once source-string debt is 0"))
        XCTAssertTrue(document.localizedStandardContains("Once there is no P0/P1 or user-visible stability fix"))
        XCTAssertTrue(document.localizedStandardContains("stop post-stable refactor"))
    }

    func testStopConditionListsOnlyAllowedPostStableWork() throws {
        let document = try stopConditionDocument()
        let allowedScopes = [
            "P0/P1",
            "release delivery issue",
            "notarization / installation",
            "user-visible stability",
            "clearly bounded tech-debt with measurable risk reduction"
        ]

        for scope in allowedScopes {
            XCTAssertTrue(document.localizedStandardContains(scope), "Missing allowed scope: \(scope)")
        }
    }

    func testStopConditionDoesNotBecomeRefactorPermission() throws {
        let document = try stopConditionDocument()

        XCTAssertTrue(document.localizedStandardContains("Do not use this document as permission to continue refactoring"))
        XCTAssertTrue(document.localizedStandardContains("No production code changes"))
        XCTAssertTrue(document.localizedStandardContains("No new UI"))
        XCTAssertTrue(document.localizedStandardContains("No release changes"))
    }

    private func stopConditionDocument() throws -> String {
        let url = try repositoryRoot(filePath: #filePath)
            .appendingPathComponent("docs/architecture/post-stable-stop-condition.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing post-stable stop-condition document")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
