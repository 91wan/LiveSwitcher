import XCTest
@testable import LiveSwitcher

final class AgendaMarkerInputTests: XCTestCase {
    func testNormalizedInputTrimsTitleAndPreservesExplicitSchedule() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let input = AgendaMarkerInput(
            title: "  茶歇  ",
            scheduledStartAt: start,
            duration: 15 * 60
        )

        let normalized = try XCTUnwrap(input.normalized())

        XCTAssertEqual(normalized.title, "茶歇")
        XCTAssertEqual(normalized.scheduledStartAt, start)
        XCTAssertEqual(normalized.duration, 15 * 60)
    }

    func testNormalizedInputAcceptsQuickTitlesAndClampsDurationBoundaries() throws {
        for title in ["茶歇", "转场", "提醒"] {
            let normalized = try XCTUnwrap(AgendaMarkerInput(
                title: title,
                scheduledStartAt: nil,
                duration: 30
            ).normalized())

            XCTAssertEqual(normalized.title, title)
            XCTAssertNil(normalized.scheduledStartAt)
            XCTAssertEqual(normalized.duration, 60)
        }

        let maxDuration = try XCTUnwrap(AgendaMarkerInput(
            title: "最长",
            scheduledStartAt: nil,
            duration: 1_000 * 60
        ).normalized())

        XCTAssertEqual(maxDuration.duration, 999 * 60)
    }

    func testNormalizedInputRejectsEmptyAndOverlongTitles() {
        XCTAssertNil(AgendaMarkerInput(
            title: "   ",
            scheduledStartAt: nil,
            duration: 15 * 60
        ).normalized())

        XCTAssertNil(AgendaMarkerInput(
            title: String(repeating: "长", count: 41),
            scheduledStartAt: nil,
            duration: 15 * 60
        ).normalized())
    }
}
