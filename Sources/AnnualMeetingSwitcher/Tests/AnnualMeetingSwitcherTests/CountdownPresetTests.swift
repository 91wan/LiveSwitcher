import XCTest
@testable import LiveSwitcher

@MainActor
final class CountdownPresetTests: XCTestCase {
    func testPresetCreationTrimsTitleAndKeepsDuration() {
        let preset = CountdownPreset.make(
            title: "  开场倒计时  ",
            totalSeconds: 630,
            orderIndex: 2
        )

        XCTAssertEqual(preset?.title, "开场倒计时")
        XCTAssertEqual(preset?.totalSeconds, 630)
        XCTAssertEqual(preset?.orderIndex, 2)
    }

    func testPresetCreationUsesDefaultTitleWhenBlank() {
        let preset = CountdownPreset.make(title: "  ", totalSeconds: 60, orderIndex: 0)

        XCTAssertEqual(preset?.title, "活动即将开始")
    }

    func testPresetCreationRejectsInvalidDuration() {
        XCTAssertNil(CountdownPreset.make(title: "Zero", totalSeconds: 0, orderIndex: 0))
        XCTAssertNil(CountdownPreset.make(
            title: "Too long",
            totalSeconds: OverlayUIState.maxCountdownSeconds + 1,
            orderIndex: 0
        ))
    }

    func testViewModelSavesLoadsAndDeletesCountdownPresets() {
        let suite = "CountdownPresetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let writer = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        XCTAssertTrue(writer.saveCountdownPreset(title: "开场", totalSeconds: 300))
        XCTAssertTrue(writer.saveCountdownPreset(title: "茶歇", totalSeconds: 900))

        let reader = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertEqual(reader.countdownPresets.map(\.title), ["开场", "茶歇"])
        XCTAssertEqual(reader.countdownPresets.map(\.totalSeconds), [300, 900])
        XCTAssertEqual(reader.countdownPresets.map(\.orderIndex), [0, 1])

        let deletedID = reader.countdownPresets[0].id
        reader.deleteCountdownPreset(id: deletedID)

        let afterDelete = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        XCTAssertEqual(afterDelete.countdownPresets.map(\.title), ["茶歇"])
        XCTAssertEqual(afterDelete.countdownPresets.map(\.orderIndex), [0])
    }

    func testLoadingPresetUpdatesComposerDraftSelection() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        XCTAssertTrue(viewModel.saveCountdownPreset(title: "开场", totalSeconds: 630))

        let preset = viewModel.countdownPresets[0]
        viewModel.loadCountdownPreset(preset)

        XCTAssertEqual(viewModel.overlayComposerState.selectedKind, .countdown)
        XCTAssertEqual(viewModel.overlayComposerState.selectedCountdownPresetID, preset.id)
        XCTAssertEqual(viewModel.overlayComposerState.countdownTitleDraft, "开场")
        XCTAssertEqual(viewModel.overlayComposerState.countdownMinutesDraft, 10)
        XCTAssertEqual(viewModel.overlayComposerState.countdownSecondsDraft, 30)
    }

    func testStartingPresetUsesSanitizedTitleWithoutLeakingTitleIntoSupportEventDetail() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        XCTAssertTrue(viewModel.saveCountdownPreset(title: "  开场倒计时  ", totalSeconds: 75))

        let preset = viewModel.countdownPresets[0]
        viewModel.startCountdownPreset(preset)

        XCTAssertTrue(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownTitle, "开场倒计时")
        XCTAssertEqual(viewModel.countdownSeconds, 75)
        XCTAssertFalse(viewModel.supportEvents.contains { event in
            event.detail.contains("开场倒计时")
        })

        viewModel.stopCountdown()
    }
}
