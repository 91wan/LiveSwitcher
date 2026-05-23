import XCTest
@testable import LiveSwitcher

final class OverlayUIStateTests: XCTestCase {
    func testLowerThirdEmptyNameProducesDisabledReason() {
        XCTAssertEqual(
            OverlayUIState.lowerThirdDisabledReason(name: "   ", isLive: false),
            "Enter a name before sending the lower third live."
        )
        XCTAssertNil(OverlayUIState.lowerThirdDisabledReason(name: "Host", isLive: false))
    }

    func testTickerEmptyTextProducesDisabledReason() {
        XCTAssertEqual(
            OverlayUIState.tickerDisabledReason(text: "\n\t", isLive: false),
            "Enter ticker text before starting."
        )
        XCTAssertNil(OverlayUIState.tickerDisabledReason(text: "Welcome", isLive: false))
    }

    func testCountdownNonPositiveDurationProducesDisabledReason() {
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(totalSeconds: 0, isLive: false),
            "Set a positive countdown duration before starting."
        )
        XCTAssertNil(OverlayUIState.countdownDisabledReason(totalSeconds: 1, isLive: false))
    }

    func testCountdownInputRejectsNegativeValues() {
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(minutes: -1, seconds: 0, isLive: false),
            "Countdown values cannot be negative."
        )
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(minutes: 0, seconds: -1, isLive: false),
            "Countdown values cannot be negative."
        )
    }

    func testCountdownInputRejectsSecondsAboveFiftyNine() {
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(minutes: 1, seconds: 60, isLive: false),
            "Seconds must be between 0 and 59."
        )
    }

    func testCountdownInputRejectsDurationsAboveMax() {
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(minutes: 1000, seconds: 0, isLive: false),
            "Countdown cannot exceed 999:59."
        )
        XCTAssertNil(OverlayUIState.countdownDisabledReason(minutes: 999, seconds: 59, isLive: false))
    }

    func testLiveOverlayReasonsPreventDuplicateStart() {
        XCTAssertEqual(
            OverlayUIState.lowerThirdDisabledReason(name: "Host", isLive: true),
            "Lower third is already live."
        )
        XCTAssertEqual(
            OverlayUIState.tickerDisabledReason(text: "Welcome", isLive: true),
            "Ticker is already live."
        )
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(totalSeconds: 30, isLive: true),
            "Countdown is already live."
        )
        XCTAssertEqual(
            OverlayUIState.countdownDisabledReason(minutes: 1, seconds: 0, isLive: true),
            "Countdown is already live."
        )
    }
}
