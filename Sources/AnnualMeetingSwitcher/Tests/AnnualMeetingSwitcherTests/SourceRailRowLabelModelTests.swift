import XCTest
@testable import LiveSwitcher

final class SourceRailRowLabelModelTests: XCTestCase {
    func testCurrentSourceLabelCombinesIndexRoleAndType() {
        let model = SourceRailRowLabelModel.make(
            queuePosition: 1,
            queueRole: .current,
            sourceLabel: "VIDEO"
        )

        XCTAssertEqual(model.numberText, "1")
        XCTAssertEqual(model.text, "1 · 正在播 · VIDEO")
        XCTAssertEqual(model.accessibilityLabel, "第 1 项，正在播，VIDEO")
    }

    func testNextSourceLabelCombinesIndexRoleAndType() {
        let model = SourceRailRowLabelModel.make(
            queuePosition: 2,
            queueRole: .next,
            sourceLabel: "HTML"
        )

        XCTAssertEqual(model.numberText, "2")
        XCTAssertEqual(model.text, "2 · 下一项 · HTML")
        XCTAssertEqual(model.accessibilityLabel, "第 2 项，下一项，HTML")
    }

    func testQueuedSourceLabelUsesIndexAndTypeOnly() {
        let model = SourceRailRowLabelModel.make(
            queuePosition: 3,
            queueRole: .queued,
            sourceLabel: "PPTX"
        )

        XCTAssertEqual(model.numberText, "3")
        XCTAssertEqual(model.text, "3 · PPTX")
        XCTAssertEqual(model.accessibilityLabel, "第 3 项，PPTX")
    }

    func testIndexesUsePlainArabicNumeralsThroughLargeQueues() {
        for position in [1, 9, 10, 20, 99] {
            let model = SourceRailRowLabelModel.make(
                queuePosition: position,
                queueRole: .queued,
                sourceLabel: "VIDEO"
            )

            XCTAssertEqual(model.numberText, "\(position)")
            XCTAssertEqual(model.text, "\(position) · VIDEO")
            XCTAssertFalse(model.text.unicodeScalars.contains { scalar in
                (0x2460...0x2473).contains(Int(scalar.value))
            })
        }
    }
}
