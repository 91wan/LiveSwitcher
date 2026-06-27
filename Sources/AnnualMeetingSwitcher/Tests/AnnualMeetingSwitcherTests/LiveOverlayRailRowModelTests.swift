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
        XCTAssertEqual(model.presetLabel, "新建人名条")
        XCTAssertEqual(model.presetInteraction, .create(.lowerThird))
        XCTAssertTrue(model.isPlaceholder)
        XCTAssertFalse(model.canToggle)
        XCTAssertEqual(model.toggleText, "上屏")
        XCTAssertEqual(model.disabledHint, "请先选择人名条预设。")
        XCTAssertEqual(model.accessibilityLabel, "人名条, 新建人名条, 上屏")
    }

    func testEmptyCountdownUsesSpecificCreateCopyAndAction() {
        let model = LiveOverlayRailRowModel.countdown(
            presets: [],
            selectedID: nil,
            isLive: false
        )

        XCTAssertEqual(model.presetLabel, "新建倒计时")
        XCTAssertEqual(model.presetInteraction, .create(.countdown))
        XCTAssertTrue(model.isPlaceholder)
        XCTAssertFalse(model.canToggle)
    }

    func testEmptyTickerUsesSpecificCreateCopyAndAction() {
        let model = LiveOverlayRailRowModel.ticker(
            presets: [],
            selectedID: nil,
            isLive: false
        )

        XCTAssertEqual(model.presetLabel, "新建游动字幕")
        XCTAssertEqual(model.presetInteraction, .create(.ticker))
        XCTAssertTrue(model.isPlaceholder)
        XCTAssertFalse(model.canToggle)
    }

    func testSelectedLowerThirdShowsPresetNameAndEnablesToggle() throws {
        let preset = try XCTUnwrap(LowerThirdPreset.make(
            name: "王五",
            role: "董事长",
            organization: "示例集团",
            orderIndex: 0
        ))

        let model = LiveOverlayRailRowModel.lowerThird(
            presets: [preset],
            selectedID: preset.id,
            isLive: true
        )

        XCTAssertEqual(model.presetLabel, "王五 · 董事长 · 示例集团")
        XCTAssertEqual(model.presetInteraction, .choose)
        XCTAssertFalse(model.isPlaceholder)
        XCTAssertTrue(model.canToggle)
        XCTAssertEqual(model.toggleText, "关闭")
        XCTAssertEqual(model.accessibilityLabel, "人名条, 王五 · 董事长 · 示例集团, 关闭")
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
        XCTAssertEqual(model.presetInteraction, .choose)
        XCTAssertTrue(model.canToggle)
        XCTAssertEqual(model.toggleText, "上屏")
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
        XCTAssertEqual(model.presetInteraction, .choose)
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
        XCTAssertEqual(model.presetInteraction, .choose)
        XCTAssertTrue(model.isPlaceholder)
        XCTAssertFalse(model.canToggle)
    }

    func testActiveOverlayRowsRemainDismissibleWithoutSelectedPreset() {
        let lowerThird = LiveOverlayRailRowModel.lowerThird(
            presets: [],
            selectedID: nil,
            isLive: true
        )
        let countdown = LiveOverlayRailRowModel.countdown(
            presets: [],
            selectedID: nil,
            isLive: true
        )
        let ticker = LiveOverlayRailRowModel.ticker(
            presets: [],
            selectedID: nil,
            isLive: true
        )

        for model in [lowerThird, countdown, ticker] {
            XCTAssertTrue(model.isPlaceholder)
            XCTAssertTrue(model.canToggle)
            XCTAssertEqual(model.toggleText, "关闭")
            XCTAssertTrue(model.accessibilityLabel.hasSuffix("关闭"))
        }
    }

    func testLiveModePresetCreationUsesStructuredInteractionInsteadOfDisplayCopy() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveQuickRail+Overlays.swift")

        XCTAssertTrue(source.contains("switch model.presetInteraction"))
        XCTAssertTrue(source.contains("case .create(let kind):"))
        XCTAssertFalse(source.contains("model.presetLabel =="))
        XCTAssertFalse(source.contains("\"+ 新建预设\""))
    }

    func testOverlayCreationCopyDoesNotUseGenericPresetLabels() throws {
        let source = try [
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Overlays/LowerThirdComposerCard.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Overlays/CountdownComposerCard.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Overlays/TickerComposerCard.swift"
        ].map(repositorySource).joined(separator: "\n")

        XCTAssertTrue(source.contains("新建人名条"))
        XCTAssertTrue(source.contains("新建倒计时"))
        XCTAssertTrue(source.contains("新建游动字幕"))
        XCTAssertFalse(source.contains("Label(\"新建预设\""))
        XCTAssertFalse(source.contains("新建倒计时预设"))
        XCTAssertFalse(source.contains("新建游动字幕预设"))
    }
}
