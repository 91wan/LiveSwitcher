import XCTest
@testable import LiveSwitcher

@MainActor
final class LowerThirdPresetTests: XCTestCase {
    func testPresetCreationTrimsNameAndSubtitle() {
        let preset = LowerThirdPreset.make(
            name: "  张三  ",
            subtitle: "  主持人  ",
            orderIndex: 2
        )

        XCTAssertEqual(preset?.name, "张三")
        XCTAssertEqual(preset?.subtitle, "主持人")
        XCTAssertEqual(preset?.orderIndex, 2)
    }

    func testPresetCreationRejectsEmptyName() {
        XCTAssertNil(LowerThirdPreset.make(name: "  ", subtitle: "主持人", orderIndex: 0))
    }

    func testViewModelSavesLoadsAndDeletesLowerThirdPresets() {
        let suite = "LowerThirdPresetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let writer = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        XCTAssertTrue(writer.saveLowerThirdPreset(name: "张三", subtitle: "主持人"))
        XCTAssertTrue(writer.saveLowerThirdPreset(name: "王五", subtitle: "董事长"))

        let reader = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertEqual(reader.lowerThirdPresets.map(\.name), ["张三", "王五"])
        XCTAssertEqual(reader.lowerThirdPresets.map(\.orderIndex), [0, 1])

        let deletedID = reader.lowerThirdPresets[0].id
        reader.deleteLowerThirdPreset(id: deletedID)

        let afterDelete = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        XCTAssertEqual(afterDelete.lowerThirdPresets.map(\.name), ["王五"])
        XCTAssertEqual(afterDelete.lowerThirdPresets.map(\.orderIndex), [0])
    }

    func testLoadingPresetUpdatesComposerDraftSelection() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        XCTAssertTrue(viewModel.saveLowerThirdPreset(name: "张三", subtitle: "主持人"))

        let preset = viewModel.lowerThirdPresets[0]
        viewModel.loadLowerThirdPreset(preset)

        XCTAssertEqual(viewModel.overlayComposerState.selectedKind, .lowerThird)
        XCTAssertEqual(viewModel.overlayComposerState.selectedLowerThirdPresetID, preset.id)
        XCTAssertEqual(viewModel.overlayComposerState.lowerThirdNameDraft, "张三")
        XCTAssertEqual(viewModel.overlayComposerState.lowerThirdTitleDraft, "主持人")
    }

    func testShowingPresetUsesSanitizedContentWithoutLeakingTextIntoSupportEventDetail() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        XCTAssertTrue(viewModel.saveLowerThirdPreset(name: "  张三  ", subtitle: "  主持人  "))

        let preset = viewModel.lowerThirdPresets[0]
        viewModel.showLowerThirdPreset(preset)

        XCTAssertTrue(viewModel.isLowerThirdVisible)
        XCTAssertEqual(viewModel.lowerThirdName, "张三")
        XCTAssertEqual(viewModel.lowerThirdTitle, "主持人")
        XCTAssertFalse(viewModel.supportEvents.contains { event in
            event.detail.contains("张三") || event.detail.contains("主持人")
        })
    }
}
