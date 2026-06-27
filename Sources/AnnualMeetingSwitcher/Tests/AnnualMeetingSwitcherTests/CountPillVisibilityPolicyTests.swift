import XCTest
@testable import LiveSwitcher

final class CountPillVisibilityPolicyTests: XCTestCase {
    func testZeroCountsAreHiddenEvenWhenEmptyStateWarnsElsewhere() {
        XCTAssertFalse(CountPillVisibilityPolicy.shouldShow(count: 0))
        XCTAssertFalse(CountPillVisibilityPolicy.shouldShow(count: -1))
    }

    func testPositiveCountsRemainVisible() {
        XCTAssertTrue(CountPillVisibilityPolicy.shouldShow(count: 1))
        XCTAssertTrue(CountPillVisibilityPolicy.shouldShow(count: 7))
    }

    func testNoisyRunDeskCountPillsUseVisibilityPolicy() throws {
        for relativePath in [
            "Views/LeftPanel.swift",
            "Views/LiveSourceRail.swift",
            "Views/ProgramMonitor/ProgramMonitorWallpaperTray.swift"
        ] {
            let source = try sourceText(relativePath)
            XCTAssertTrue(
                source.contains("CountPillVisibilityPolicy.shouldShow"),
                "\(relativePath) should hide zero count pills through the shared policy."
            )
        }
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
