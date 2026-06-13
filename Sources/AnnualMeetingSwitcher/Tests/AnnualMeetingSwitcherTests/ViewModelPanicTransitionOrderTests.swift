import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelPanicTransitionOrderTests: XCTestCase {
    func testBGMIsNotPausedImmediatelyWhenFadeDurationIsPositive() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        startBGM(bgm, in: viewModel)

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(pauseBGMEffectCount(in: viewModel), 0)
    }

    func testBGMIsPausedAfterFadeDelayWhenPanicStillActive() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        startBGM(bgm, in: viewModel)

        viewModel.togglePanicMode()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertEqual(pauseBGMEffectCount(in: viewModel), 1)
    }

    func testDelayedBGMPauseDoesNotRunAfterPanicDeactivated() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        startBGM(bgm, in: viewModel)

        viewModel.togglePanicMode()
        viewModel.togglePanicMode()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))

        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(pauseBGMEffectCount(in: viewModel), 0)
    }

    func testDelayedBGMPauseDoesNotRunForStaleGeneration() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        startBGM(bgm, in: viewModel)

        viewModel.togglePanicMode()
        var state = viewModel.runtime.state
        state.panic.generation += 1
        viewModel.runtime.replaceStateForFacadeSync(state)
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(pauseBGMEffectCount(in: viewModel), 0)
    }

    func testDelayedBGMPauseDoesNotRunWhenBGMChanged() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.liveAudioFadeDuration = 0.05
        viewModel.bgmItems = [first, second]
        startBGM(first, in: viewModel)

        viewModel.togglePanicMode()
        viewModel.toggleBGM(second)
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertEqual(pauseBGMEffectCount(in: viewModel), 0)
    }

    func testZeroFadeDurationPausesBGMImmediately() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0
        startBGM(bgm, in: viewModel)

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertEqual(pauseBGMEffectCount(in: viewModel), 1)
    }

    private func makeViewModel() -> SwitcherViewModel {
        SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }

    private func startBGM(_ bgm: BGMItem, in viewModel: SwitcherViewModel) {
        if !viewModel.bgmItems.contains(where: { $0.id == bgm.id }) {
            viewModel.bgmItems.append(bgm)
        }
        viewModel.toggleBGM(bgm)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    private func pauseBGMEffectCount(in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.recordedEffects.filter {
            if case .pauseBGM = $0 { return true }
            return false
        }.count
    }
}
