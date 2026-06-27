import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelOverlaySmokeTests: SwitcherViewModelSmokeTestCase {
    func testTickerAndLowerThirdStateTransitions() {
        let viewModel = makeViewModel()

        viewModel.startTicker(text: "欢迎光临")
        XCTAssertTrue(viewModel.isTickerActive)
        XCTAssertEqual(viewModel.tickerText, "欢迎光临")

        viewModel.stopTicker()
        XCTAssertFalse(viewModel.isTickerActive)

        viewModel.showLowerThird(name: "主持人", role: "开场", organization: "示例科技")
        XCTAssertTrue(viewModel.isLowerThirdVisible)
        XCTAssertEqual(viewModel.lowerThirdName, "主持人")
        XCTAssertEqual(viewModel.lowerThirdRole, "开场")
        XCTAssertEqual(viewModel.lowerThirdOrganization, "示例科技")

        viewModel.dismissLowerThird()
        XCTAssertFalse(viewModel.isLowerThirdVisible)
    }


    func testCountdownStartAndStopResetState() {
        let viewModel = makeViewModel()

        viewModel.startCountdown(seconds: 10, title: "即将开始")
        XCTAssertTrue(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownTitle, "即将开始")
        XCTAssertEqual(viewModel.countdownSeconds, 10)

        viewModel.stopCountdown()
        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownSeconds, 0)
    }


    func testCountdownTickAutoStopsAtZero() {
        let viewModel = makeViewModel()

        viewModel.startCountdown(seconds: 2, title: "开场倒计时")

        viewModel.countdownTick()
        XCTAssertTrue(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownSeconds, 1)

        viewModel.countdownTick()
        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownSeconds, 0)
    }


    func testRestartingCountdownReplacesRemainingSeconds() {
        let viewModel = makeViewModel()

        viewModel.startCountdown(seconds: 30, title: "First")
        viewModel.countdownTick()
        XCTAssertEqual(viewModel.countdownSeconds, 29)

        viewModel.startCountdown(seconds: 5, title: "Second")

        XCTAssertTrue(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownTitle, "Second")
        XCTAssertEqual(viewModel.countdownSeconds, 5)
    }


    func testOverlayStartMethodsRejectUnsafeInput() {
        let viewModel = makeViewModel()

        viewModel.startTicker(text: "   ")
        XCTAssertFalse(viewModel.isTickerActive)

        viewModel.showLowerThird(name: "   ", role: "", organization: "主持")
        XCTAssertFalse(viewModel.isLowerThirdVisible)

        viewModel.startCountdown(seconds: 0, title: "即将开始")
        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownSeconds, 0)

        viewModel.startCountdown(seconds: -5, title: "即将开始")
        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownSeconds, 0)
    }


    func testClearAllOverlaysResetsCountdownTickerAndLowerThird() {
        let viewModel = makeViewModel()

        viewModel.startCountdown(seconds: 30, title: "准备开始")
        viewModel.startTicker(text: "欢迎光临")
        viewModel.showLowerThird(name: "主持人", role: "", organization: "开场")

        XCTAssertTrue(viewModel.isCountdownActive)
        XCTAssertTrue(viewModel.isTickerActive)
        XCTAssertTrue(viewModel.isLowerThirdVisible)

        let supportEventCountBeforeClear = viewModel.supportEvents.count
        viewModel.clearAllOverlays()
        let clearEvents = Array(viewModel.supportEvents.dropFirst(supportEventCountBeforeClear))

        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertNil(viewModel.countdownTimer)
        XCTAssertEqual(viewModel.countdownSeconds, 0)
        XCTAssertFalse(viewModel.isTickerActive)
        XCTAssertFalse(viewModel.isLowerThirdVisible)
        XCTAssertEqual(viewModel.lowerThirdName, "")
        XCTAssertEqual(viewModel.lowerThirdRole, "")
        XCTAssertEqual(viewModel.lowerThirdOrganization, "")
        XCTAssertEqual(clearEvents.map(\.kind), [.overlaysCleared])
        XCTAssertEqual(clearEvents.map(\.detail), ["state=cleared"])
    }

}
