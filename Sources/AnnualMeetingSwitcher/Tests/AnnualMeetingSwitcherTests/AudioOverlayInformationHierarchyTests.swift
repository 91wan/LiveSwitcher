import XCTest
@testable import LiveSwitcher

final class AudioOverlayInformationHierarchyTests: XCTestCase {
    func testAudioPageDefinesMixerRoutingAndBGMLibrarySections() {
        let model = AudioMixerPageModel(
            masterVolume: 0.5,
            mediaVolume: 0.7,
            mediaEffectiveVolume: 0.35,
            bgmVolume: 0.25,
            bgmEffectiveVolume: 0.0,
            strategy: .followProgram,
            isPanicMode: false,
            isSpeakerMode: false,
            isBGMAudioTakeoverActive: true
        )

        XCTAssertEqual(model.sectionTitles, ["调音台", "音频策略", "BGM 库"])
        XCTAssertEqual(model.selectedStrategyText, AudioStrategy.followProgram.displayTitle)
        XCTAssertEqual(model.activeLimiterText, "BGM 接管")
        XCTAssertTrue(model.routingStatusText.contains(AudioStrategy.followProgram.displayTitle))
        XCTAssertTrue(model.routingStatusText.contains("BGM 接管"))
        XCTAssertEqual(model.routingImpactText, "当前策略：音频跟随；限制器：BGM 接管。媒体声道被临时静音。")
        XCTAssertEqual(model.routingStatusKind, .warn)
    }

    func testAudioRoutingStrategySummaryIsIdleWhenNoEmergencyRoutingIsActive() {
        let model = AudioMixerPageModel(
            masterVolume: 0.5,
            mediaVolume: 0.7,
            mediaEffectiveVolume: 0.35,
            bgmVolume: 0.25,
            bgmEffectiveVolume: 0.25,
            strategy: .mixed,
            isPanicMode: false,
            isSpeakerMode: false,
            isBGMAudioTakeoverActive: false
        )

        XCTAssertEqual(model.routingStatusText, AudioStrategy.mixed.displayTitle)
        XCTAssertEqual(model.selectedStrategyText, AudioStrategy.mixed.displayTitle)
        XCTAssertEqual(model.activeLimiterText, "无")
        XCTAssertEqual(model.effectiveRoutingSummary, "混合 · 无限制器")
        XCTAssertEqual(model.routingStatusKind, .idle)
        XCTAssertEqual(model.channelLimitText, "无强制静音")
        XCTAssertEqual(model.routingImpactText, "没有应急路由；实际输出跟随当前策略和推子。")
    }

    func testInlineWarningBannerIconMatchesStatusKind() {
        XCTAssertEqual(InlineWarningBanner(title: "Ready", message: "", kind: .ready).iconName, "checkmark.seal.fill")
        XCTAssertEqual(InlineWarningBanner(title: "Warn", message: "", kind: .warn).iconName, "exclamationmark.triangle.fill")
        XCTAssertEqual(InlineWarningBanner(title: "Fail", message: "", kind: .fail).iconName, "xmark.octagon.fill")
        XCTAssertEqual(InlineWarningBanner(title: "Live", message: "", kind: .live).iconName, "dot.radiowaves.left.and.right")
        XCTAssertEqual(InlineWarningBanner(title: "Idle", message: "", kind: .idle).iconName, "info.circle.fill")
        XCTAssertEqual(InlineWarningBanner(title: "Muted", message: "", kind: .muted).iconName, "info.circle.fill")
    }

    func testAudioPageNoLongerReusesOldRightPanelMixerRail() throws {
        let content = try String(contentsOf: sourceURL("Views/AudioMixerView.swift"), encoding: .utf8)

        XCTAssertTrue(content.contains("MixerFaderCard"))
        XCTAssertTrue(content.contains("RoutingStrategyCard"))
        XCTAssertTrue(content.contains("BGMLibraryCard"))
        XCTAssertFalse(content.contains("RightPanel(mode: .fullMixer)"))
    }

    func testOverlayComposerStateKeepsDraftsWhenSwitchingTools() {
        var state = OverlayComposerState()
        state.lowerThirdNameDraft = "Guest A"
        state.lowerThirdTitleDraft = "Keynote"
        state.tickerTextDraft = "Welcome ticker"
        state.select(.ticker)
        state.select(.lowerThird)

        XCTAssertEqual(state.selectedKind, .lowerThird)
        XCTAssertEqual(state.visibleComposerTitles, ["人名条"])
        XCTAssertEqual(state.lowerThirdNameDraft, "Guest A")
        XCTAssertEqual(state.lowerThirdTitleDraft, "Keynote")
        XCTAssertEqual(state.tickerTextDraft, "Welcome ticker")
    }

    @MainActor
    func testOverlayComposerDraftLivesInViewModel() throws {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.overlayComposerState.lowerThirdNameDraft = "Guest A"
        viewModel.overlayComposerState.tickerTextDraft = "Welcome ticker"
        viewModel.selectedMainTab = .audioMixer
        viewModel.selectedMainTab = .overlays

        XCTAssertEqual(viewModel.overlayComposerState.lowerThirdNameDraft, "Guest A")
        XCTAssertEqual(viewModel.overlayComposerState.tickerTextDraft, "Welcome ticker")

        let overlayView = try String(contentsOf: sourceURL("Views/OverlayControlPanel.swift"), encoding: .utf8)
        XCTAssertFalse(overlayView.contains("@State private var composerState = OverlayComposerState()"))
        XCTAssertTrue(overlayView.contains("viewModel.overlayComposerState"))
    }

    func testOverlayPageUsesSingleComposerAndActiveStackClearAction() throws {
        let content = try String(contentsOf: sourceURL("Views/OverlayControlPanel.swift"), encoding: .utf8)

        XCTAssertTrue(content.contains("OverlayComposerKind.allCases"))
        XCTAssertTrue(content.contains("activeStackCard"))
        XCTAssertFalse(content.contains("全部下屏 / Clear all"))
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
