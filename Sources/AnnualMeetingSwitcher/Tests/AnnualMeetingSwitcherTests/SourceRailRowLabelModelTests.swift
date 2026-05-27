import XCTest
@testable import LiveSwitcher

final class SourceRailRowLabelModelTests: XCTestCase {
    func testCurrentSourceLabelCombinesIndexRoleAndType() {
        let model = SourceRailRowLabelModel.make(
            queuePosition: 1,
            queueRole: .current,
            sourceLabel: "VIDEO"
        )

        XCTAssertEqual(model.text, "① · 正在播 · VIDEO")
        XCTAssertEqual(model.accessibilityLabel, "第 1 项，正在播，VIDEO")
    }

    func testNextSourceLabelCombinesIndexRoleAndType() {
        let model = SourceRailRowLabelModel.make(
            queuePosition: 2,
            queueRole: .next,
            sourceLabel: "HTML"
        )

        XCTAssertEqual(model.text, "② · 下一项 · HTML")
        XCTAssertEqual(model.accessibilityLabel, "第 2 项，下一项，HTML")
    }

    func testQueuedSourceLabelUsesIndexAndTypeOnly() {
        let model = SourceRailRowLabelModel.make(
            queuePosition: 3,
            queueRole: .queued,
            sourceLabel: "PPTX"
        )

        XCTAssertEqual(model.text, "③ · PPTX")
        XCTAssertEqual(model.accessibilityLabel, "第 3 项，PPTX")
    }

    func testLargeIndexesFallBackToArabicNumerals() {
        let model = SourceRailRowLabelModel.make(
            queuePosition: 21,
            queueRole: .queued,
            sourceLabel: "VIDEO"
        )

        XCTAssertEqual(model.text, "21 · VIDEO")
    }
}
