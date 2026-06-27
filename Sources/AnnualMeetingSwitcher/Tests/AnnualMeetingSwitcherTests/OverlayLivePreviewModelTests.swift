import XCTest
@testable import LiveSwitcher

final class OverlayLivePreviewModelTests: XCTestCase {
    func testDefaultAllOffPreviewHasNoOverlayLayers() {
        let model = OverlayLivePreviewModel.make(
            isLowerThirdVisible: false,
            lowerThirdName: "",
            lowerThirdRole: "",
            lowerThirdOrganization: "",
            isCountdownActive: false,
            countdownSeconds: 0,
            countdownTitle: "",
            isTickerActive: false,
            tickerText: "Welcome · The program will begin shortly",
            composerState: OverlayComposerState()
        )

        XCTAssertTrue(model.layers.isEmpty)
        XCTAssertEqual(model.emptyMessage, "没有上屏叠层")
        XCTAssertFalse(model.accessibilityLabel.contains("Welcome"))
    }

    func testActiveOutputStateCreatesMatchingPreviewLayers() {
        let model = OverlayLivePreviewModel.make(
            isLowerThirdVisible: true,
            lowerThirdName: "Host",
            lowerThirdRole: "CEO",
            lowerThirdOrganization: "Example Inc.",
            isCountdownActive: true,
            countdownSeconds: 90,
            countdownTitle: "Starts soon",
            isTickerActive: true,
            tickerText: "Doors closing",
            composerState: OverlayComposerState()
        )

        XCTAssertEqual(model.layers.map(\.kind), [.ticker, .countdown, .lowerThird])
        XCTAssertEqual(model.layers.first(where: { $0.kind == .ticker })?.primaryText, "Doors closing")
        XCTAssertEqual(model.layers.first(where: { $0.kind == .countdown })?.primaryText, "01:30")
        XCTAssertEqual(model.layers.first(where: { $0.kind == .lowerThird })?.primaryText, "Host")
        XCTAssertEqual(model.layers.first(where: { $0.kind == .lowerThird })?.secondaryText, "CEO · Example Inc.")
        XCTAssertTrue(model.layers.allSatisfy { !$0.isDraft && $0.opacity == 1 })
        XCTAssertTrue(model.accessibilityLabel.contains("叠层预览"))
        XCTAssertTrue(model.accessibilityLabel.contains("上屏"))
    }

    func testLowerThirdPreviewSecondaryTextCoversOptionalRoleAndOrganization() {
        let cases: [(role: String, organization: String, expected: String?)] = [
            ("", "", nil),
            ("主持人", "", "主持人"),
            ("", "示例科技", "示例科技"),
            ("主持人", "示例科技", "主持人 · 示例科技")
        ]

        for item in cases {
            let model = OverlayLivePreviewModel.make(
                isLowerThirdVisible: true,
                lowerThirdName: "张三",
                lowerThirdRole: item.role,
                lowerThirdOrganization: item.organization,
                isCountdownActive: false,
                countdownSeconds: 0,
                countdownTitle: "",
                isTickerActive: false,
                tickerText: "",
                composerState: OverlayComposerState()
            )

            XCTAssertEqual(model.layers.first(where: { $0.kind == .lowerThird })?.secondaryText, item.expected)
        }
    }

    func testSelectedDraftCanRenderDimmedWithoutLookingLive() {
        var draft = OverlayComposerState()
        draft.selectedKind = .lowerThird
        draft.lowerThirdNameDraft = "Upcoming Guest"
        draft.lowerThirdRoleDraft = "Panel"
        draft.lowerThirdOrganizationDraft = "Forum"

        let model = OverlayLivePreviewModel.make(
            isLowerThirdVisible: false,
            lowerThirdName: "",
            lowerThirdRole: "",
            lowerThirdOrganization: "",
            isCountdownActive: false,
            countdownSeconds: 0,
            countdownTitle: "",
            isTickerActive: false,
            tickerText: "",
            composerState: draft
        )

        XCTAssertEqual(model.layers.count, 1)
        XCTAssertEqual(model.layers[0].kind, .lowerThird)
        XCTAssertEqual(model.layers[0].secondaryText, "Panel · Forum")
        XCTAssertTrue(model.layers[0].isDraft)
        XCTAssertEqual(model.layers[0].opacity, 0.35)
    }

    func testOverlayControlPanelUsesSharedPreviewCanvasAndPrimarySendLiveCTA() throws {
        let source = try [
            "Views/OverlayControlPanel.swift",
            "Views/Overlays/OverlayLivePreviewColumn.swift"
        ].map(sourceText).joined(separator: "\n")

        XCTAssertTrue(source.contains("OverlayLivePreviewCanvas("))
        XCTAssertFalse(source.contains("private var tickerPreview"))
        XCTAssertFalse(source.contains("private var countdownPreview"))
        XCTAssertFalse(source.contains("private var lowerThirdPreview"))
        XCTAssertFalse(source.contains("fill: StudioTheme.Tone.live"))
        XCTAssertFalse(source.contains("fill: StudioTheme.Tone.warn"))
    }

    func testOverlayActionButtonKeepsDisabledTintHierarchy() throws {
        let source = try sourceText("Views/Overlays/OverlayComposerControls.swift")

        XCTAssertTrue(source.contains(".foregroundStyle(isDisabled ? .white.opacity(0.55) : .white)"))
        XCTAssertTrue(source.contains(".fill(isDisabled ? fill.opacity(0.25) : fill)"))
        XCTAssertFalse(source.contains("StudioTheme.Tone.muted.opacity(0.45)"))
    }

    func testOverlayEmptyPreviewUsesCompactCanvasSizing() throws {
        let source = try sourceText("Views/Overlays/OverlayLivePreviewColumn.swift")

        XCTAssertTrue(source.contains("let previewModel = livePreviewModel"))
        XCTAssertTrue(source.contains("let isEmptyPreview = previewModel.layers.isEmpty"))
        XCTAssertTrue(source.contains(".frame(maxWidth: isEmptyPreview ? 320 : .infinity)"))
        XCTAssertTrue(source.contains(".frame(height: isEmptyPreview ? 180 : nil)"))
    }

    func testOverlayComposerTitleUsesSharedTypeScale() throws {
        let source = try sourceText("Views/OverlayControlPanel.swift")

        XCTAssertTrue(source.contains(".font(StudioTheme.TypeScale.title)"))
        XCTAssertFalse(source.contains(".font(.system(size: 24, weight: .bold))"))
    }

    func testAppExposesPasteSpeakersFromClipboardCommand() throws {
        let source = try sourceText("App.swift")

        XCTAssertTrue(source.contains("从剪贴板粘贴主持人"))
        XCTAssertTrue(source.contains("NSPasteboard.general.string(forType: .string)"))
        XCTAssertTrue(source.contains(".keyboardShortcut(\"v\", modifiers: [.command, .shift])"))
        XCTAssertTrue(source.contains("viewModel.importLowerThirdSpeakersFromClipboardText"))
    }

    func testLiveOverlayCanBeReplacedBySendLiveWhenDraftIsValid() {
        XCTAssertNil(OverlayUIState.lowerThirdDisabledReason(name: "Host", isLive: true))
        XCTAssertNil(OverlayUIState.tickerDisabledReason(text: "Welcome", isLive: true))
        XCTAssertNil(OverlayUIState.countdownDisabledReason(totalSeconds: 30, isLive: true))
        XCTAssertNil(OverlayUIState.countdownDisabledReason(minutes: 1, seconds: 0, isLive: true))
    }

    @MainActor
    func testOverlayPresetDraftActionsRoundTripThroughViewModelBehavior() throws {
        let suite = "OverlayPresetDraftActions.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        viewModel.overlayComposerState.lowerThirdNameDraft = "  张三  "
        viewModel.overlayComposerState.lowerThirdRoleDraft = "  主持人  "
        viewModel.overlayComposerState.lowerThirdOrganizationDraft = "  示例科技  "
        XCTAssertTrue(viewModel.saveLowerThirdPresetFromDraft())
        let lowerThird = try XCTUnwrap(viewModel.lowerThirdPresets.first)
        viewModel.clearLowerThirdPresetDraft()
        viewModel.loadLowerThirdPreset(lowerThird)
        XCTAssertEqual(viewModel.overlayComposerState.lowerThirdNameDraft, "张三")
        XCTAssertEqual(viewModel.overlayComposerState.lowerThirdRoleDraft, "主持人")
        XCTAssertEqual(viewModel.overlayComposerState.lowerThirdOrganizationDraft, "示例科技")
        XCTAssertEqual(viewModel.overlayComposerState.selectedLowerThirdPresetID, lowerThird.id)

        let imported = try SpeakerImportService.parse(text: "name,role,organization\n李四,嘉宾,研发中心")
        let importResult = viewModel.importLowerThirdPresets(imported)
        XCTAssertEqual(importResult.importedNames, ["李四"])
        XCTAssertTrue(viewModel.exportLowerThirdPresetsCSV().contains("李四,嘉宾,研发中心"))

        viewModel.overlayComposerState.countdownTitleDraft = "  开场倒计时  "
        viewModel.overlayComposerState.countdownMinutesDraft = 1
        viewModel.overlayComposerState.countdownSecondsDraft = 15
        XCTAssertTrue(viewModel.saveCountdownPresetFromDraft())
        let countdown = try XCTUnwrap(viewModel.countdownPresets.first)
        viewModel.clearCountdownPresetDraft()
        viewModel.loadCountdownPreset(countdown)
        XCTAssertEqual(viewModel.overlayComposerState.countdownTitleDraft, "开场倒计时")
        XCTAssertEqual(viewModel.overlayComposerState.countdownMinutesDraft, 1)
        XCTAssertEqual(viewModel.overlayComposerState.countdownSecondsDraft, 15)
        XCTAssertEqual(viewModel.overlayComposerState.selectedCountdownPresetID, countdown.id)

        viewModel.overlayComposerState.tickerTextDraft = "  欢迎莅临  "
        viewModel.overlayComposerState.tickerSpeedIndex = 2
        XCTAssertTrue(viewModel.saveTickerPresetFromDraft())
        let ticker = try XCTUnwrap(viewModel.tickerPresets.first)
        viewModel.clearTickerPresetDraft()
        viewModel.loadTickerPreset(ticker)
        XCTAssertEqual(viewModel.overlayComposerState.tickerTextDraft, "欢迎莅临")
        XCTAssertEqual(viewModel.overlayComposerState.tickerSpeedIndex, 2)
        XCTAssertEqual(viewModel.overlayComposerState.selectedTickerPresetID, ticker.id)
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
