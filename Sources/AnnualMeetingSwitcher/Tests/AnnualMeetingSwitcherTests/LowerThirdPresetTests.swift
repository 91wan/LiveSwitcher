import XCTest
@testable import LiveSwitcher

@MainActor
final class LowerThirdPresetTests: XCTestCase {
    func testPresetCreationTrimsNameRoleAndOrganization() {
        let preset = LowerThirdPreset.make(
            name: "  张三  ",
            role: "  总经理  ",
            organization: "  示例科技有限公司  ",
            orderIndex: 2
        )

        XCTAssertEqual(preset?.name, "张三")
        XCTAssertEqual(preset?.role, "总经理")
        XCTAssertEqual(preset?.organization, "示例科技有限公司")
        XCTAssertEqual(preset?.orderIndex, 2)
    }

    func testPresetCreationRejectsEmptyName() {
        XCTAssertNil(LowerThirdPreset.make(name: "  ", role: "主持人", organization: "示例科技", orderIndex: 0))
    }

    func testLegacySubtitleJSONMigratesToOrganizationWithoutLosingPreset() throws {
        let id = UUID()
        let json = """
        [
          {"id":"\(id.uuidString)","name":" 张三 ","subtitle":" 示例科技有限公司 ","orderIndex":4}
        ]
        """.data(using: .utf8)!

        let presets = try JSONDecoder().decode([LowerThirdPreset].self, from: json)

        XCTAssertEqual(presets.count, 1)
        XCTAssertEqual(presets[0].id, id)
        XCTAssertEqual(presets[0].name, "张三")
        XCTAssertEqual(presets[0].role, "")
        XCTAssertEqual(presets[0].organization, "示例科技有限公司")
        XCTAssertEqual(presets[0].orderIndex, 4)
    }

    func testNewJSONRoundTripsRoleAndOrganizationWithoutWritingLegacySubtitle() throws {
        let preset = try XCTUnwrap(LowerThirdPreset.make(
            name: "张三",
            role: "总经理",
            organization: "示例科技有限公司",
            orderIndex: 1
        ))

        let data = try JSONEncoder().encode([preset])
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let decoded = try JSONDecoder().decode([LowerThirdPreset].self, from: data)

        XCTAssertEqual(decoded, [preset])
        XCTAssertTrue(json.contains("\"role\""))
        XCTAssertTrue(json.contains("\"organization\""))
        XCTAssertFalse(json.contains("\"subtitle\""))
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
        XCTAssertTrue(writer.saveLowerThirdPreset(name: "张三", role: "主持人", organization: "示例科技"))
        XCTAssertTrue(writer.saveLowerThirdPreset(name: "王五", role: "董事长", organization: "示例集团"))

        let reader = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertEqual(reader.lowerThirdPresets.map(\.name), ["张三", "王五"])
        XCTAssertEqual(reader.lowerThirdPresets.map(\.role), ["主持人", "董事长"])
        XCTAssertEqual(reader.lowerThirdPresets.map(\.organization), ["示例科技", "示例集团"])
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
        XCTAssertTrue(viewModel.saveLowerThirdPreset(name: "张三", role: "主持人", organization: "示例科技"))

        let preset = viewModel.lowerThirdPresets[0]
        viewModel.loadLowerThirdPreset(preset)

        XCTAssertEqual(viewModel.overlayComposerState.selectedKind, .lowerThird)
        XCTAssertEqual(viewModel.overlayComposerState.selectedLowerThirdPresetID, preset.id)
        XCTAssertEqual(viewModel.overlayComposerState.lowerThirdNameDraft, "张三")
        XCTAssertEqual(viewModel.overlayComposerState.lowerThirdRoleDraft, "主持人")
        XCTAssertEqual(viewModel.overlayComposerState.lowerThirdOrganizationDraft, "示例科技")
    }

    func testShowingPresetUsesSanitizedContentWithoutLeakingTextIntoSupportEventDetail() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        XCTAssertTrue(viewModel.saveLowerThirdPreset(name: "  张三  ", role: "  主持人  ", organization: "  示例科技  "))

        let preset = viewModel.lowerThirdPresets[0]
        viewModel.showLowerThirdPreset(preset)

        XCTAssertTrue(viewModel.isLowerThirdVisible)
        XCTAssertEqual(viewModel.lowerThirdName, "张三")
        XCTAssertEqual(viewModel.lowerThirdRole, "主持人")
        XCTAssertEqual(viewModel.lowerThirdOrganization, "示例科技")
        XCTAssertFalse(viewModel.supportEvents.contains { event in
            event.detail.contains("张三") || event.detail.contains("主持人") || event.detail.contains("示例科技")
        })
    }

    func testShowAndClearLowerThirdUsesThreeCurrentFields() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.showLowerThird(name: " 张三 ", role: " 主持人 ", organization: " 示例科技 ")

        XCTAssertTrue(viewModel.isLowerThirdVisible)
        XCTAssertEqual(viewModel.lowerThirdName, "张三")
        XCTAssertEqual(viewModel.lowerThirdRole, "主持人")
        XCTAssertEqual(viewModel.lowerThirdOrganization, "示例科技")

        viewModel.clearAllOverlays()

        XCTAssertFalse(viewModel.isLowerThirdVisible)
        XCTAssertEqual(viewModel.lowerThirdName, "")
        XCTAssertEqual(viewModel.lowerThirdRole, "")
        XCTAssertEqual(viewModel.lowerThirdOrganization, "")
    }
}
