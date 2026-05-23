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

        XCTAssertEqual(model.sectionTitles, ["Mixer", "Routing Strategy", "BGM Library"])
        XCTAssertEqual(model.routingImpactText, "BGM takeover is active: media is muted while BGM plays.")
        XCTAssertEqual(model.routingStatusKind, .warn)
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
        XCTAssertEqual(state.visibleComposerTitles, ["Lower Third"])
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
