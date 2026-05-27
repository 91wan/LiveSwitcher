import XCTest
@testable import LiveSwitcher

final class LiveOverlayRailRowModelTests: XCTestCase {
    func testEmptyLowerThirdUsesNewPresetCopyAndDisablesToggle() {
        let model = LiveOverlayRailRowModel.lowerThird(
            presets: [],
            selectedID: nil,
            isLive: false
        )

        XCTAssertEqual(model.title, "人名条")
        XCTAssertEqual(model.presetLabel, "+ 新建预设")
        XCTAssertTrue(model.isPlaceholder)
        XCTAssertFalse(model.canToggle)
        XCTAssertEqual(model.toggleText, "关闭")
        XCTAssertEqual(model.disabledHint, "请先选择人名条预设。")
    }

    func testSelectedLowerThirdShowsPresetNameAndEnablesToggle() throws {
        let preset = try XCTUnwrap(LowerThirdPreset.make(
            name: "王五",
            subtitle: "董事长",
            orderIndex: 0
        ))

        let model = LiveOverlayRailRowModel.lowerThird(
            presets: [preset],
            selectedID: preset.id,
            isLive: true
        )

        XCTAssertEqual(model.presetLabel, "王五 · 董事长")
        XCTAssertFalse(model.isPlaceholder)
        XCTAssertTrue(model.canToggle)
        XCTAssertEqual(model.toggleText, "上屏")
        XCTAssertEqual(model.accessibilityLabel, "人名条, 王五 · 董事长, 上屏")
    }

    func testCountdownLabelIncludesFormattedDuration() throws {
        let preset = try XCTUnwrap(CountdownPreset.make(
            title: "Opening",
            totalSeconds: 625,
            orderIndex: 0
        ))

        let model = LiveOverlayRailRowModel.countdown(
            presets: [preset],
            selectedID: preset.id,
            isLive: false
        )

        XCTAssertEqual(model.presetLabel, "Opening 10:25")
        XCTAssertTrue(model.canToggle)
        XCTAssertEqual(model.toggleText, "关闭")
    }

    func testTickerLabelTruncatesLongText() throws {
        let preset = try XCTUnwrap(TickerPreset.make(
            text: "Welcome to the annual meeting and award ceremony",
            speedIndex: 1,
            orderIndex: 0
        ))

        let model = LiveOverlayRailRowModel.ticker(
            presets: [preset],
            selectedID: preset.id,
            isLive: false
        )

        XCTAssertEqual(model.presetLabel, "Welcome to the annual...")
        XCTAssertTrue(model.canToggle)
    }

    func testAvailablePresetsWithoutSelectedPresetPromptForChoice() throws {
        let preset = try XCTUnwrap(TickerPreset.make(
            text: "Welcome",
            speedIndex: 1,
            orderIndex: 0
        ))

        let model = LiveOverlayRailRowModel.ticker(
            presets: [preset],
            selectedID: nil,
            isLive: false
        )

        XCTAssertEqual(model.presetLabel, "选择预设...")
        XCTAssertTrue(model.isPlaceholder)
        XCTAssertFalse(model.canToggle)
    }
}
