import XCTest
@testable import LiveSwitcher

@MainActor
final class TickerPresetTests: XCTestCase {
    func testPresetCreationTrimsTextAndClampsSpeedIndex() {
        let preset = TickerPreset.make(
            text: "  Welcome ticker  ",
            speedIndex: 99,
            orderIndex: 2
        )

        XCTAssertEqual(preset?.text, "Welcome ticker")
        XCTAssertEqual(preset?.speedIndex, OverlaySpeedSelection.options.count - 1)
        XCTAssertEqual(preset?.orderIndex, 2)
    }

    func testPresetCreationRejectsBlankText() {
        XCTAssertNil(TickerPreset.make(text: "\n\t", speedIndex: 1, orderIndex: 0))
    }

    func testViewModelSavesLoadsAndDeletesTickerPresets() {
        let suite = "TickerPresetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let writer = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        XCTAssertTrue(writer.saveTickerPreset(text: "Welcome", speedIndex: 0))
        XCTAssertTrue(writer.saveTickerPreset(text: "Closing", speedIndex: 2))

        let reader = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertEqual(reader.tickerPresets.map(\.text), ["Welcome", "Closing"])
        XCTAssertEqual(reader.tickerPresets.map(\.speedIndex), [0, 2])
        XCTAssertEqual(reader.tickerPresets.map(\.orderIndex), [0, 1])

        let deletedID = reader.tickerPresets[0].id
        reader.deleteTickerPreset(id: deletedID)

        let afterDelete = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        XCTAssertEqual(afterDelete.tickerPresets.map(\.text), ["Closing"])
        XCTAssertEqual(afterDelete.tickerPresets.map(\.orderIndex), [0])
    }

    func testLoadingPresetUpdatesComposerDraftAndViewModelSpeed() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        XCTAssertTrue(viewModel.saveTickerPreset(text: "Welcome", speedIndex: 2))

        let preset = viewModel.tickerPresets[0]
        viewModel.loadTickerPreset(preset)

        XCTAssertEqual(viewModel.overlayComposerState.selectedKind, .ticker)
        XCTAssertEqual(viewModel.overlayComposerState.selectedTickerPresetID, preset.id)
        XCTAssertEqual(viewModel.overlayComposerState.tickerTextDraft, "Welcome")
        XCTAssertEqual(viewModel.overlayComposerState.tickerSpeedIndex, 2)
        XCTAssertEqual(viewModel.tickerSpeed, OverlaySpeedSelection.speed(at: 2))
    }

    func testStartingPresetUsesSanitizedTextAndSpeedWithoutLeakingTextIntoSupportEventDetail() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        XCTAssertTrue(viewModel.saveTickerPreset(text: "  Welcome ticker  ", speedIndex: 0))

        let preset = viewModel.tickerPresets[0]
        viewModel.startTickerPreset(preset)

        XCTAssertTrue(viewModel.isTickerActive)
        XCTAssertEqual(viewModel.tickerText, "Welcome ticker")
        XCTAssertEqual(viewModel.tickerSpeed, OverlaySpeedSelection.speed(at: 0))
        XCTAssertFalse(viewModel.supportEvents.contains { event in
            event.detail.localizedStandardContains("Welcome ticker")
        })

        viewModel.stopTicker()
    }
}
