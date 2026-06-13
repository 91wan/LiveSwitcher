import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelPanicTransitionOrderTests: XCTestCase {
    func testBGMIsNotPausedImmediatelyWhenFadeDurationIsPositive() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        viewModel.currentBGMItem = bgm
        viewModel.isBGMPlaying = true

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(actionCount("operatorPausedBGMForPanic", in: viewModel), 0)
    }

    func testBGMIsPausedAfterFadeDelayWhenPanicStillActive() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        viewModel.currentBGMItem = bgm
        viewModel.isBGMPlaying = true

        viewModel.togglePanicMode()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertEqual(actionCount("operatorPausedBGMForPanic", in: viewModel), 1)
    }

    func testDelayedBGMPauseDoesNotRunAfterPanicDeactivated() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        viewModel.currentBGMItem = bgm
        viewModel.isBGMPlaying = true

        viewModel.togglePanicMode()
        viewModel.togglePanicMode()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))

        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(actionCount("operatorPausedBGMForPanic", in: viewModel), 0)
    }

    func testDelayedBGMPauseDoesNotRunForStaleGeneration() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        viewModel.currentBGMItem = bgm
        viewModel.isBGMPlaying = true

        viewModel.togglePanicMode()
        viewModel.panicAudioTransitionGeneration += 1
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(actionCount("operatorPausedBGMForPanic", in: viewModel), 0)
    }

    func testDelayedBGMPauseDoesNotRunWhenBGMChanged() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.liveAudioFadeDuration = 0.05
        viewModel.currentBGMItem = first
        viewModel.isBGMPlaying = true

        viewModel.togglePanicMode()
        viewModel.currentBGMItem = second
        viewModel.isBGMPlaying = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(actionCount("operatorPausedBGMForPanic", in: viewModel), 0)
    }

    func testZeroFadeDurationPausesBGMImmediately() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0
        viewModel.currentBGMItem = bgm
        viewModel.isBGMPlaying = true

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertEqual(actionCount("operatorPausedBGMForPanic", in: viewModel), 1)
    }

    private func makeViewModel() -> SwitcherViewModel {
        SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }

    private func actionCount(_ name: String, in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.actionLog.filter { $0.actionName == name }.count
    }
}
