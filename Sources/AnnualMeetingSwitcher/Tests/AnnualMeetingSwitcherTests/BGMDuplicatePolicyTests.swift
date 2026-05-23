import XCTest
@testable import LiveSwitcher

final class BGMDuplicatePolicyTests: XCTestCase {
    func testSameTitleDifferentPathIsImportable() {
        let existing = [
            BGMItem(title: "Opening", url: URL(fileURLWithPath: "/tmp/show-a/Opening.mp3"), category: .warmUp)
        ]
        let candidate = URL(fileURLWithPath: "/tmp/show-b/Opening.mp3")

        let decision = BGMDuplicatePolicy.decision(for: candidate, existingItems: existing)

        XCTAssertEqual(decision, .importable(title: "Opening"))
    }

    func testSameFileURLIsSkippedAsDuplicate() {
        let url = URL(fileURLWithPath: "/tmp/show/Opening.mp3")
        let existing = [
            BGMItem(title: "Opening", url: url, category: .warmUp)
        ]

        let decision = BGMDuplicatePolicy.decision(for: url, existingItems: existing)

        XCTAssertEqual(decision, .duplicateURL)
    }
}
