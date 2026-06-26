import XCTest
@testable import LiveSwitcher

final class ProgramMonitorBlackoutStatusModelTests: XCTestCase {
    func testNoneWhenBlackoutIsInactive() {
        let model = ProgramMonitorBlackoutStatusModel.make(
            isFadeToBlackActive: false,
            isPanicMode: false
        )

        XCTAssertEqual(model.kind, .none)
        XCTAssertEqual(model.title, "")
        XCTAssertNil(model.subtitle)
        XCTAssertEqual(model.statusKind, .idle)
        XCTAssertNil(model.monitorAccessibilityLabel)
    }

    func testFadeToBlackStatusCopyAndTone() {
        let model = ProgramMonitorBlackoutStatusModel.make(
            isFadeToBlackActive: true,
            isPanicMode: false
        )

        XCTAssertEqual(model.kind, .fadeToBlack)
        XCTAssertEqual(model.title, "切黑中")
        XCTAssertEqual(model.subtitle, "观众正在看到黑场")
        XCTAssertEqual(model.statusKind, .warn)
        XCTAssertEqual(model.monitorAccessibilityLabel, "主输出监看：切黑已启用")
    }

    func testPanicStatusTakesPriorityOverFadeToBlack() {
        let model = ProgramMonitorBlackoutStatusModel.make(
            isFadeToBlackActive: true,
            isPanicMode: true
        )

        XCTAssertEqual(model.kind, .panic)
        XCTAssertEqual(model.title, "紧急切黑")
        XCTAssertEqual(model.subtitle, "观众正在看到黑场")
        XCTAssertEqual(model.statusKind, .fail)
        XCTAssertEqual(model.monitorAccessibilityLabel, "主输出监看：紧急切黑已启用")
    }
}
