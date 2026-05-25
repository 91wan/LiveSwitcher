import XCTest
@testable import LiveSwitcher

final class LiveOverlayRailRowModelTests: XCTestCase {
    func testEmptyLowerThirdUsesNewPresetCopyAndDisablesToggle() {
        let model = LiveOverlayRailRowModel.lowerThird(
            presets: [],
            selectedID: nil,
            isLive: false
        )

        XCTAssertEqual(model.title, "Lower Third")
        XCTAssertEqual(model.presetLabel, "+ New preset")
        XCTAssertTrue(model.isPlaceholder)
        XCTAssertFalse(model.canToggle)
        XCTAssertEqual(model.toggleText, "OFF")
        XCTAssertEqual(model.disabledHint, "Choose a lower third preset first.")
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

        XCTAssertEqual(model.presetLabel, "王五")
        XCTAssertFalse(model.isPlaceholder)
        XCTAssertTrue(model.canToggle)
        XCTAssertEqual(model.toggleText, "LIVE")
        XCTAssertEqual(model.accessibilityLabel, "Lower Third, 王五, LIVE")
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
        XCTAssertEqual(model.toggleText, "OFF")
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

        XCTAssertEqual(model.presetLabel, "Choose preset...")
        XCTAssertTrue(model.isPlaceholder)
        XCTAssertFalse(model.canToggle)
    }
}
