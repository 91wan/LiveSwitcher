import XCTest
@testable import LiveSwitcher

@MainActor
final class OverlayLivePreviewModelTests: XCTestCase {
    func testDefaultAllOffPreviewHasNoOverlayLayers() {
        let model = previewModel()

        XCTAssertTrue(model.layers.isEmpty)
        XCTAssertEqual(model.emptyMessage, "没有上屏叠层")
        XCTAssertEqual(model.accessibilityLabel, "没有上屏叠层")
    }

    func testActiveOutputStateCreatesMatchingPreviewLayersInStackOrder() {
        let model = previewModel(
            isLowerThirdVisible: true,
            lowerThirdName: " Host ",
            lowerThirdRole: " CEO ",
            lowerThirdOrganization: " Example Inc. ",
            isCountdownActive: true,
            countdownSeconds: 90,
            countdownTitle: " Starts soon ",
            isTickerActive: true,
            tickerText: " Doors closing "
        )

        XCTAssertEqual(model.layers.map(\.kind), [.ticker, .countdown, .lowerThird])
        XCTAssertEqual(model.layers.first(where: { $0.kind == .ticker })?.primaryText, "Doors closing")
        XCTAssertEqual(model.layers.first(where: { $0.kind == .countdown })?.primaryText, "01:30")
        XCTAssertEqual(model.layers.first(where: { $0.kind == .countdown })?.secondaryText, "Starts soon")
        XCTAssertEqual(model.layers.first(where: { $0.kind == .lowerThird })?.primaryText, "Host")
        XCTAssertEqual(model.layers.first(where: { $0.kind == .lowerThird })?.secondaryText, "CEO · Example Inc.")
        XCTAssertTrue(model.layers.allSatisfy { !$0.isDraft && $0.opacity == 1 })
        XCTAssertTrue(model.accessibilityLabel.contains("叠层预览"))
        XCTAssertTrue(model.accessibilityLabel.contains("上屏 人名条: Host"))
    }

    func testLowerThirdPreviewSecondaryTextCoversOptionalRoleAndOrganization() {
        let cases: [(role: String, organization: String, expected: String?)] = [
            ("", "", nil),
            ("主持人", "", "主持人"),
            ("", "示例科技", "示例科技"),
            ("主持人", "示例科技", "主持人 · 示例科技")
        ]

        for item in cases {
            let model = previewModel(
                isLowerThirdVisible: true,
                lowerThirdName: "张三",
                lowerThirdRole: item.role,
                lowerThirdOrganization: item.organization
            )

            XCTAssertEqual(model.layers.first(where: { $0.kind == .lowerThird })?.secondaryText, item.expected)
        }
    }

    func testDraftPreviewRendersOnlySelectedNonLiveKindAsDimmedLayer() {
        var draft = OverlayComposerState()
        draft.selectedKind = .countdown
        draft.countdownTitleDraft = "  开场倒计时  "
        draft.countdownMinutesDraft = 1
        draft.countdownSecondsDraft = 15

        let countdownDraft = previewModel(composerState: draft)
        XCTAssertEqual(countdownDraft.layers.map(\.kind), [.countdown])
        XCTAssertEqual(countdownDraft.layers[0].primaryText, "01:15")
        XCTAssertEqual(countdownDraft.layers[0].secondaryText, "开场倒计时")
        XCTAssertTrue(countdownDraft.layers[0].isDraft)
        XCTAssertEqual(countdownDraft.layers[0].opacity, 0.35)

        draft.selectedKind = .ticker
        draft.tickerTextDraft = "  欢迎莅临  "
        let tickerDraft = previewModel(composerState: draft)
        XCTAssertEqual(tickerDraft.layers.map(\.kind), [.ticker])
        XCTAssertEqual(tickerDraft.layers[0].primaryText, "欢迎莅临")
        XCTAssertTrue(tickerDraft.layers[0].isDraft)
    }

    func testDraftPreviewIsSuppressedWhenSameOverlayKindIsAlreadyLive() {
        var draft = OverlayComposerState()
        draft.selectedKind = .lowerThird
        draft.lowerThirdNameDraft = "Upcoming Guest"
        draft.lowerThirdRoleDraft = "Panel"
        draft.lowerThirdOrganizationDraft = "Forum"

        let model = previewModel(
            isLowerThirdVisible: true,
            lowerThirdName: "Live Host",
            lowerThirdRole: "Host",
            lowerThirdOrganization: "",
            composerState: draft
        )

        XCTAssertEqual(model.layers.count, 1)
        XCTAssertEqual(model.layers[0].primaryText, "Live Host")
        XCTAssertFalse(model.layers[0].isDraft)
    }

    func testTickerPreviewGeometryStartsOffscreenAndResetsBehindFullTextWidth() {
        let geometry = TickerTrackGeometry(containerWidth: 1920, measuredTextWidth: 640)

        XCTAssertEqual(geometry.initialOffsetA, 1920 + TickerTrackGeometry.internalTextPadding, accuracy: 0.001)
        XCTAssertGreaterThan(geometry.initialOffsetA, 1920)
        XCTAssertEqual(geometry.initialOffsetB, geometry.initialOffsetA + 640 + TickerTrackGeometry.trackGap, accuracy: 0.001)
        XCTAssertEqual(geometry.resetThreshold, -640, accuracy: 0.001)
        XCTAssertEqual(geometry.nextOffset(after: 0), geometry.initialOffsetA, accuracy: 0.001)
    }

    func testOverlayLiveStateFacadeMaintainsActiveOverlayCountAndClearAllState() {
        let viewModel = makeViewModel()

        viewModel.showLowerThird(name: "  张三  ", role: "  主持人  ", organization: "  示例科技  ")
        viewModel.startCountdown(seconds: 30, title: "  开场  ")
        viewModel.startTicker(text: "  欢迎莅临  ")

        XCTAssertEqual(viewModel.livePreflightSnapshot.activeOverlayCount, 3)
        XCTAssertEqual(viewModel.livePreflightSnapshot.activeOverlayKinds, [.countdown, .ticker, .lowerThird])
        XCTAssertEqual(viewModel.lowerThirdName, "张三")
        XCTAssertEqual(viewModel.lowerThirdRole, "主持人")
        XCTAssertEqual(viewModel.lowerThirdOrganization, "示例科技")
        XCTAssertEqual(viewModel.countdownTitle, "开场")
        XCTAssertEqual(viewModel.tickerText, "欢迎莅临")

        viewModel.clearAllOverlays()

        XCTAssertEqual(viewModel.livePreflightSnapshot.activeOverlayCount, 0)
        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertFalse(viewModel.isTickerActive)
        XCTAssertFalse(viewModel.isLowerThirdVisible)
        XCTAssertEqual(viewModel.lowerThirdName, "")
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .overlaysCleared })
    }

    func testOverlayPresetDraftActionsRoundTripThroughViewModelBehavior() throws {
        let viewModel = makeViewModel()

        viewModel.overlayComposerState.lowerThirdNameDraft = "  张三  "
        viewModel.overlayComposerState.lowerThirdRoleDraft = "  主持人  "
        viewModel.overlayComposerState.lowerThirdOrganizationDraft = "  示例科技  "
        XCTAssertTrue(viewModel.saveLowerThirdPresetFromDraft())
        let lowerThird = try XCTUnwrap(viewModel.lowerThirdPresets.first)
        viewModel.clearLowerThirdPresetDraft()
        viewModel.loadLowerThirdPreset(lowerThird)
        XCTAssertEqual(viewModel.overlayComposerState.lowerThirdNameDraft, "张三")
        XCTAssertEqual(viewModel.overlayComposerState.selectedLowerThirdPresetID, lowerThird.id)

        viewModel.overlayComposerState.countdownTitleDraft = "  开场倒计时  "
        viewModel.overlayComposerState.countdownMinutesDraft = 1
        viewModel.overlayComposerState.countdownSecondsDraft = 15
        XCTAssertTrue(viewModel.saveCountdownPresetFromDraft())
        let countdown = try XCTUnwrap(viewModel.countdownPresets.first)
        viewModel.clearCountdownPresetDraft()
        viewModel.loadCountdownPreset(countdown)
        XCTAssertEqual(viewModel.overlayComposerState.countdownTitleDraft, "开场倒计时")
        XCTAssertEqual(viewModel.overlayComposerState.countdownTotalSeconds, 75)
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

    private func previewModel(
        isLowerThirdVisible: Bool = false,
        lowerThirdName: String = "",
        lowerThirdRole: String = "",
        lowerThirdOrganization: String = "",
        isCountdownActive: Bool = false,
        countdownSeconds: Int = 0,
        countdownTitle: String = "",
        isTickerActive: Bool = false,
        tickerText: String = "",
        composerState: OverlayComposerState = OverlayComposerState()
    ) -> OverlayLivePreviewModel {
        OverlayLivePreviewModel.make(
            isLowerThirdVisible: isLowerThirdVisible,
            lowerThirdName: lowerThirdName,
            lowerThirdRole: lowerThirdRole,
            lowerThirdOrganization: lowerThirdOrganization,
            isCountdownActive: isCountdownActive,
            countdownSeconds: countdownSeconds,
            countdownTitle: countdownTitle,
            isTickerActive: isTickerActive,
            tickerText: tickerText,
            composerState: composerState
        )
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "OverlayLivePreviewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }
}
