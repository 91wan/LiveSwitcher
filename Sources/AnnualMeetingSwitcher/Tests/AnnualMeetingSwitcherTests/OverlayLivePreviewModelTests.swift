import XCTest
@testable import LiveSwitcher

final class OverlayLivePreviewModelTests: XCTestCase {
    func testDefaultAllOffPreviewHasNoOverlayLayers() {
        let model = OverlayLivePreviewModel.make(
            isLowerThirdVisible: false,
            lowerThirdName: "",
            lowerThirdTitle: "",
            isCountdownActive: false,
            countdownSeconds: 0,
            countdownTitle: "",
            isTickerActive: false,
            tickerText: "Welcome · The program will begin shortly",
            composerState: OverlayComposerState()
        )

        XCTAssertTrue(model.layers.isEmpty)
        XCTAssertEqual(model.emptyMessage, "No live overlays")
        XCTAssertFalse(model.accessibilityLabel.contains("Welcome"))
    }

    func testActiveOutputStateCreatesMatchingPreviewLayers() {
        let model = OverlayLivePreviewModel.make(
            isLowerThirdVisible: true,
            lowerThirdName: "Host",
            lowerThirdTitle: "CEO",
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
        XCTAssertTrue(model.layers.allSatisfy { !$0.isDraft && $0.opacity == 1 })
    }

    func testSelectedDraftCanRenderDimmedWithoutLookingLive() {
        var draft = OverlayComposerState()
        draft.selectedKind = .lowerThird
        draft.lowerThirdNameDraft = "Upcoming Guest"
        draft.lowerThirdTitleDraft = "Panel"

        let model = OverlayLivePreviewModel.make(
            isLowerThirdVisible: false,
            lowerThirdName: "",
            lowerThirdTitle: "",
            isCountdownActive: false,
            countdownSeconds: 0,
            countdownTitle: "",
            isTickerActive: false,
            tickerText: "",
            composerState: draft
        )

        XCTAssertEqual(model.layers.count, 1)
        XCTAssertEqual(model.layers[0].kind, .lowerThird)
        XCTAssertTrue(model.layers[0].isDraft)
        XCTAssertEqual(model.layers[0].opacity, 0.35)
    }

    func testOverlayControlPanelUsesSharedPreviewCanvasAndPrimarySendLiveCTA() throws {
        let source = try sourceText("Views/OverlayControlPanel.swift")

        XCTAssertTrue(source.contains("OverlayLivePreviewCanvas("))
        XCTAssertFalse(source.contains("private var tickerPreview"))
        XCTAssertFalse(source.contains("private var countdownPreview"))
        XCTAssertFalse(source.contains("private var lowerThirdPreview"))
        XCTAssertFalse(source.contains("fill: StudioTheme.Tone.live"))
        XCTAssertFalse(source.contains("fill: StudioTheme.Tone.warn"))
    }

    func testOverlayActionButtonKeepsDisabledTintHierarchy() throws {
        let source = try sourceText("Views/OverlayControlPanel.swift")

        XCTAssertTrue(source.contains(".foregroundStyle(isDisabled ? .white.opacity(0.55) : .white)"))
        XCTAssertTrue(source.contains(".fill(isDisabled ? fill.opacity(0.25) : fill)"))
        XCTAssertFalse(source.contains("StudioTheme.Tone.muted.opacity(0.45)"))
    }

    func testOverlayEmptyPreviewUsesCompactCanvasSizing() throws {
        let source = try sourceText("Views/OverlayControlPanel.swift")

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

    func testOverlayComposerExposesLowerThirdPresetShelf() throws {
        let source = try sourceText("Views/OverlayControlPanel.swift")

        XCTAssertTrue(source.contains("lowerThirdPresetShelf"))
        XCTAssertTrue(source.contains("Save Preset"))
        XCTAssertTrue(source.contains("New Preset"))
        XCTAssertTrue(source.contains("Delete Preset"))
        XCTAssertTrue(source.contains("Import..."))
        XCTAssertTrue(source.contains("Export..."))
        XCTAssertTrue(source.contains("NSOpenPanel"))
        XCTAssertTrue(source.contains("NSSavePanel"))
        XCTAssertTrue(source.contains("viewModel.loadLowerThirdPreset(preset)"))
        XCTAssertTrue(source.contains("viewModel.saveLowerThirdPresetFromDraft()"))
        XCTAssertTrue(source.contains("viewModel.importLowerThirdPresets"))
    }

    func testAppExposesPasteSpeakersFromClipboardCommand() throws {
        let source = try sourceText("App.swift")

        XCTAssertTrue(source.contains("Paste Speakers from Clipboard"))
        XCTAssertTrue(source.contains("NSPasteboard.general.string(forType: .string)"))
        XCTAssertTrue(source.contains(".keyboardShortcut(\"v\", modifiers: [.command, .shift])"))
        XCTAssertTrue(source.contains("viewModel.importLowerThirdSpeakersFromClipboardText"))
    }

    func testOverlayComposerExposesCountdownPresetShelf() throws {
        let source = try sourceText("Views/OverlayControlPanel.swift")

        XCTAssertTrue(source.contains("countdownPresetShelf"))
        XCTAssertTrue(source.contains("Save Countdown Preset"))
        XCTAssertTrue(source.contains("New Countdown Preset"))
        XCTAssertTrue(source.contains("Delete Countdown Preset"))
        XCTAssertTrue(source.contains("viewModel.loadCountdownPreset(preset)"))
        XCTAssertTrue(source.contains("viewModel.saveCountdownPresetFromDraft()"))
    }

    func testOverlayComposerExposesTickerPresetShelf() throws {
        let source = try sourceText("Views/OverlayControlPanel.swift")

        XCTAssertTrue(source.contains("tickerPresetShelf"))
        XCTAssertTrue(source.contains("Save Ticker Preset"))
        XCTAssertTrue(source.contains("New Ticker Preset"))
        XCTAssertTrue(source.contains("Delete Ticker Preset"))
        XCTAssertTrue(source.contains("viewModel.loadTickerPreset(preset)"))
        XCTAssertTrue(source.contains("viewModel.saveTickerPresetFromDraft()"))
    }

    func testLiveOverlayCanBeReplacedBySendLiveWhenDraftIsValid() {
        XCTAssertNil(OverlayUIState.lowerThirdDisabledReason(name: "Host", isLive: true))
        XCTAssertNil(OverlayUIState.tickerDisabledReason(text: "Welcome", isLive: true))
        XCTAssertNil(OverlayUIState.countdownDisabledReason(totalSeconds: 30, isLive: true))
        XCTAssertNil(OverlayUIState.countdownDisabledReason(minutes: 1, seconds: 0, isLive: true))
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
