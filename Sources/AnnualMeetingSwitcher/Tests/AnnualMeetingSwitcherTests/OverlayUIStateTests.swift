import XCTest
@testable import LiveSwitcher

final class OverlayUIStateTests: XCTestCase {
    func testLowerThirdEmptyNameProducesDisabledReason() {
        XCTAssertEqual(
            OverlayUIState.lowerThirdDisabledReason(name: "   ", isLive: false),
            "请输入姓名"
        )
        XCTAssertNil(OverlayUIState.lowerThirdDisabledReason(name: "Host", isLive: false))
    }

    func testTickerEmptyTextProducesDisabledReason() {
        XCTAssertEqual(
            OverlayUIState.tickerDisabledReason(text: "\n\t", isLive: false),
            "请输入字幕内容"
        )
        XCTAssertNil(OverlayUIState.tickerDisabledReason(text: "Welcome", isLive: false))
    }

    func testCountdownNonPositiveDurationProducesDisabledReason() {
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(totalSeconds: 0, isLive: false),
            "请设置有效倒计时"
        )
        XCTAssertNil(OverlayUIState.countdownDisabledReason(totalSeconds: 1, isLive: false))
    }

    func testCountdownInputRejectsNegativeValues() {
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(minutes: -1, seconds: 0, isLive: false),
            "倒计时不能为负数"
        )
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(minutes: 0, seconds: -1, isLive: false),
            "倒计时不能为负数"
        )
    }

    func testCountdownInputRejectsSecondsAboveFiftyNine() {
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(minutes: 1, seconds: 60, isLive: false),
            "秒数需为 0-59"
        )
    }

    func testCountdownInputRejectsDurationsAboveMax() {
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(minutes: 1000, seconds: 0, isLive: false),
            "倒计时不能超过 999:59"
        )
        XCTAssertNil(OverlayUIState.countdownDisabledReason(minutes: 999, seconds: 59, isLive: false))
    }

    func testLiveOverlayReasonsPreventDuplicateStart() {
        XCTAssertEqual(
            OverlayUIState.lowerThirdDisabledReason(name: "Host", isLive: true),
            "人名条已上屏"
        )
        XCTAssertEqual(
            OverlayUIState.tickerDisabledReason(text: "Welcome", isLive: true),
            "游动字幕已上屏"
        )
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(totalSeconds: 30, isLive: true),
            "倒计时已上屏"
        )
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(minutes: 1, seconds: 0, isLive: true),
            "倒计时已上屏"
        )
    }

    func testCountdownTotalSecondsReturnsNilForInvalidInput() {
        XCTAssertEqual(OverlayUIState.countdownTotalSeconds(minutes: 10, seconds: 30), 630)
        XCTAssertNil(OverlayUIState.countdownTotalSeconds(minutes: -1, seconds: 0))
        XCTAssertNil(OverlayUIState.countdownTotalSeconds(minutes: 0, seconds: 60))
        XCTAssertNil(OverlayUIState.countdownTotalSeconds(minutes: 1000, seconds: 0))
    }
}
