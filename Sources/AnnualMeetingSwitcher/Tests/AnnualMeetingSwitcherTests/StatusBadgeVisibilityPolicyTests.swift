import XCTest
@testable import LiveSwitcher

final class StatusBadgeVisibilityPolicyTests: XCTestCase {
    func testDefaultReadyAndIdleBadgesAreHidden() {
        XCTAssertFalse(StatusBadgeVisibilityPolicy.shouldShow(text: "NORMAL", kind: .ready))
        XCTAssertFalse(StatusBadgeVisibilityPolicy.shouldShow(text: "READY", kind: .ready))
        XCTAssertFalse(StatusBadgeVisibilityPolicy.shouldShow(text: "IDLE", kind: .idle))
        XCTAssertFalse(StatusBadgeVisibilityPolicy.shouldShow(text: "STANDBY", kind: .idle))
        XCTAssertFalse(StatusBadgeVisibilityPolicy.shouldShow(text: "OFF", kind: .idle))
    }

    func testExceptionAndActiveBadgesRemainVisible() {
        XCTAssertTrue(StatusBadgeVisibilityPolicy.shouldShow(text: "WARN", kind: .warn))
        XCTAssertTrue(StatusBadgeVisibilityPolicy.shouldShow(text: "DISPLAY LOST", kind: .fail))
        XCTAssertTrue(StatusBadgeVisibilityPolicy.shouldShow(text: "ON AIR", kind: .live))
        XCTAssertTrue(StatusBadgeVisibilityPolicy.shouldShow(text: "MUTED", kind: .muted))
        XCTAssertTrue(StatusBadgeVisibilityPolicy.shouldShow(text: "PLAYING", kind: .ready))
        XCTAssertTrue(StatusBadgeVisibilityPolicy.shouldShow(text: "EMPTY", kind: .warn))
    }

    func testLiveOpsAndLiveModeCardsUseVisibilityPolicy() throws {
        let liveOps = try sourceText("Views/LiveOpsPanel.swift")
        let liveMode = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(liveOps.contains("StatusBadgeVisibilityPolicy.shouldShow(text: status, kind: kind)"))
        XCTAssertTrue(liveMode.contains("StatusBadgeVisibilityPolicy.shouldShow(text: status, kind: kind)"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
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
