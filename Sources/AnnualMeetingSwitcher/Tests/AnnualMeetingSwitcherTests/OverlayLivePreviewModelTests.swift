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
