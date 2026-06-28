import CoreGraphics
import XCTest
@testable import LiveSwitcher

final class RunDeskControlConvergenceTests: XCTestCase {
    func testProgramMonitorPreviewDeckKeepsSixteenNineAtSetupWidths() {
        let setupWidths: [CGFloat] = [800, 1_200, 1_600]

        for containerWidth in setupWidths {
            let layout = ProgramMonitorPreviewDeckLayout.make(
                containerWidth: containerWidth,
                maxHeight: 342
            )

            XCTAssertEqual(layout.size.width / layout.size.height, 16.0 / 9.0, accuracy: 0.001)
            XCTAssertLessThanOrEqual(layout.size.width, containerWidth)
            XCTAssertEqual(layout.leftGutter, layout.rightGutter, accuracy: 0.001)
        }
    }

    func testProgramMonitorPreviewDeckHandlesZeroAndUnlimitedSpace() {
        let zero = ProgramMonitorPreviewDeckLayout.make(containerWidth: 0, maxHeight: 342)
        let live = ProgramMonitorPreviewDeckLayout.make(containerWidth: 1_920, maxHeight: .infinity)

        XCTAssertEqual(zero.size, .zero)
        XCTAssertEqual(zero.leftGutter, 0)
        XCTAssertEqual(zero.rightGutter, 0)
        XCTAssertEqual(live.size.width, 1_920, accuracy: 0.001)
        XCTAssertEqual(live.size.height, 1_080, accuracy: 0.001)
    }

    func testProgramMonitorChromeModelKeepsStatusCompactInsteadOfRepeatingBadges() {
        let full = ProgramMonitorChromeLayoutModel.make(width: 640)
        let compact = ProgramMonitorChromeLayoutModel.make(width: 420)
        let stateOnly = ProgramMonitorChromeLayoutModel.make(width: 240)

        XCTAssertEqual(full.variant, .full)
        XCTAssertTrue(full.showsFullInlineStatus)
        XCTAssertFalse(full.showsCompactInlineStatus)
        XCTAssertEqual(compact.variant, .compact)
        XCTAssertFalse(compact.showsFullInlineStatus)
        XCTAssertTrue(compact.showsCompactInlineStatus)
        XCTAssertEqual(stateOnly.variant, .stateOnly)
        XCTAssertFalse(stateOnly.showsFullInlineStatus)
        XCTAssertFalse(stateOnly.showsCompactInlineStatus)
    }

    func testProgramMonitorStateSummarizesPreviewLiveAndStandby() {
        let item = ProgramItem(title: "Opening", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/opening.mov"))

        XCTAssertEqual(ProgramMonitorStateModel.make(isBroadcasting: true, currentItem: item).label, "直播")
        XCTAssertEqual(ProgramMonitorStateModel.make(isBroadcasting: true, currentItem: item).kind, .live)
        XCTAssertEqual(ProgramMonitorStateModel.make(isBroadcasting: false, currentItem: item).label, "预览")
        XCTAssertEqual(ProgramMonitorStateModel.make(isBroadcasting: false, currentItem: nil).label, "待机")
    }

    func testWallpaperEmptyAndActiveStatesStayInlineAndExplicit() {
        let first = URL(fileURLWithPath: "/tmp/wallpaper-a.png")
        let second = URL(fileURLWithPath: "/tmp/wallpaper-b.png")

        let empty = LiveWallpaperQuickPickerModel.make(wallpapers: [], activeWallpaperURL: nil)
        let populated = LiveWallpaperQuickPickerModel.make(wallpapers: [first, second], activeWallpaperURL: first)

        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.displayTitle, "没有待机壁纸")
        XCTAssertEqual(empty.statusText, "无壁纸")
        XCTAssertEqual(empty.statusKind, .warn)
        XCTAssertEqual(populated.statusText, "2")
        XCTAssertEqual(populated.statusKind, .ready)
        XCTAssertEqual(populated.items.map(\.title), ["wallpaper-a.png", "wallpaper-b.png"])
        XCTAssertEqual(populated.items.map(\.isActive), [true, false])
    }

    func testSetupAudioDockOnlyAppearsOutsideAudioMixerInSetupMode() {
        XCTAssertTrue(SetupAudioDockModel.shouldShow(consoleMode: .setup, selectedTab: .preview))
        XCTAssertFalse(SetupAudioDockModel.shouldShow(consoleMode: .setup, selectedTab: .audioMixer))
        XCTAssertFalse(SetupAudioDockModel.shouldShow(consoleMode: .live, selectedTab: .preview))
    }

    func testSetupAudioDockSummarizesMutedChannelsAndEffectiveVolumes() {
        let model = SetupAudioDockModel.make(
            masterVolume: 0.74,
            mediaVolume: 0.35,
            bgmVolume: 0.2,
            effectiveMediaVolume: 0.18,
            effectiveBGMVolume: 0.07,
            isMasterMuted: false,
            isMediaMuted: true,
            isBGMMuted: true
        )

        XCTAssertEqual(model.masterUserText, "74%")
        XCTAssertEqual(model.masterEffectiveText, "74%")
        XCTAssertEqual(model.mediaUserText, "35%")
        XCTAssertEqual(model.bgmUserText, "20%")
        XCTAssertEqual(model.mediaEffectiveText, "18%")
        XCTAssertEqual(model.bgmEffectiveText, "7%")
        XCTAssertEqual(model.mutedChannelCount, 2)
    }

    func testAutoNextIdleStateIsNeutralAndActiveStateWarns() {
        let idle = AutoNextVideoControlModel.make(isEnabled: false, hasCurrentProgram: false)
        let armedWithoutProgram = AutoNextVideoControlModel.make(isEnabled: true, hasCurrentProgram: false)
        let active = AutoNextVideoControlModel.make(isEnabled: true, hasCurrentProgram: true)

        XCTAssertEqual(idle.statusKind, .idle)
        XCTAssertEqual(idle.systemImage, "play.rectangle.on.rectangle")
        XCTAssertEqual(armedWithoutProgram.statusKind, .idle)
        XCTAssertEqual(active.statusKind, .warn)
        XCTAssertEqual(active.systemImage, "exclamationmark.triangle.fill")
    }

    func testBGMIdleStatusDoesNotLookLikeASelectableBadge() {
        let track = BGMItem(title: "Opening", url: URL(fileURLWithPath: "/tmp/opening.mp3"), category: .warmUp)
        let state = BGMControlsState.make(items: [track], currentItem: nil)

        XCTAssertEqual(state.displayStatusText, "待选")
        XCTAssertEqual(state.displayStatusKind, .idle)
        XCTAssertTrue(state.canPlay)
        XCTAssertFalse(state.canSkipNext)
        XCTAssertEqual(state.skipDisabledReason, "请先选择或播放一首 BGM。")
    }

    func testBGMPlayingStatusUsesReadyTreatmentAndTransportAffordances() {
        let first = BGMItem(title: "Opening", url: URL(fileURLWithPath: "/tmp/opening.mp3"), category: .warmUp)
        let second = BGMItem(title: "Walkup", url: URL(fileURLWithPath: "/tmp/walkup.mp3"), category: .warmUp)
        let state = BGMControlsState.make(items: [first, second], currentItem: first, isPlaying: true)

        XCTAssertEqual(state.displayStatusText, "播放中")
        XCTAssertEqual(state.displayStatusKind, .ready)
        XCTAssertTrue(state.canSeekToBeginning)
        XCTAssertTrue(state.canSkipPrevious)
        XCTAssertTrue(state.canSkipNext)
        XCTAssertNil(state.playDisabledReason)
        XCTAssertNil(state.skipDisabledReason)
    }

    func testDirectorRailsUseNarrowerRunDeskWidth() {
        XCTAssertEqual(StudioTheme.directorRailWidth, 320)
        XCTAssertLessThan(StudioTheme.directorRailWidth, 360)
    }
}
