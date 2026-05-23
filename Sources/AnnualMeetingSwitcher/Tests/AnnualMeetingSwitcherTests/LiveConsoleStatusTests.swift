import XCTest
@testable import LiveSwitcher

final class LiveConsoleStatusTests: XCTestCase {
    private func snapshot(
        hasExternalDisplay: Bool = true,
        isBroadcasting: Bool = false,
        currentTitle: String? = "Opening Video",
        currentSource: String? = "Media",
        mediaVolume: Float = 0.5,
        bgmVolume: Float = 0.4,
        panic: Bool = false,
        speaker: Bool = false,
        bgmTakeover: Bool = false,
        ppt: Bool = false
    ) -> LivePreflightSnapshot {
        LivePreflightSnapshot(
            appVersion: "0.4.0",
            hasExternalDisplay: hasExternalDisplay,
            isBroadcasting: isBroadcasting,
            broadcastSafetyNotice: nil,
            programItemCount: currentTitle == nil ? 0 : 1,
            currentProgramTitle: currentTitle,
            currentProgramSource: currentSource,
            bgmItemCount: 1,
            isBGMPlaying: false,
            isBGMAudioTakeoverActive: bgmTakeover,
            isSpeakerMode: speaker,
            isPanicMode: panic,
            isPageInterceptEnabled: ppt,
            activeOverlayCount: 0,
            wallpaperCount: 1,
            autoPlayNextVideoOnEnd: false,
            effectiveMediaVolume: mediaVolume,
            effectiveBGMVolume: bgmVolume
        )
    }

    func testStatusBarShowsOnAirCurrentNextAndAudioSummary() {
        let model = LiveStatusBarModel.make(
            snapshot: snapshot(isBroadcasting: true),
            nextProgramTitle: "Awards"
        )

        XCTAssertEqual(model.projection.value, "ON AIR")
        XCTAssertEqual(model.projection.status, .live)
        XCTAssertEqual(model.current.value, "Opening Video · Media")
        XCTAssertEqual(model.current.status, .live)
        XCTAssertEqual(model.next.value, "Awards")
        XCTAssertEqual(model.next.status, .ready)
        XCTAssertEqual(model.audio.value, "Normal")
        XCTAssertEqual(model.items.map(\.title), ["Output", "Current", "Next", "Audio"])
        XCTAssertTrue(model.isCritical)
    }

    func testStatusBarFailsWhenProjectionClaimsLiveWithoutExternalDisplay() {
        let model = LiveStatusBarModel.make(
            snapshot: snapshot(hasExternalDisplay: false, isBroadcasting: true),
            nextProgramTitle: nil
        )

        XCTAssertEqual(model.projection.value, "Display Lost")
        XCTAssertEqual(model.projection.status, .fail)
        XCTAssertTrue(model.isCritical)
    }

    func testStatusBarWarnsWhenExternalDisplayMissing() {
        let model = LiveStatusBarModel.make(
            snapshot: snapshot(hasExternalDisplay: false, currentTitle: nil, currentSource: nil),
            nextProgramTitle: nil
        )

        XCTAssertEqual(model.projection.value, "No Display")
        XCTAssertEqual(model.projection.status, .warn)
        XCTAssertEqual(model.current.value, "No Program")
        XCTAssertEqual(model.current.status, .warn)
        XCTAssertEqual(model.next.value, "None")
    }

    func testStatusBarMarksPanicAsMutedAndCritical() {
        let model = LiveStatusBarModel.make(
            snapshot: snapshot(mediaVolume: 0, bgmVolume: 0, panic: true),
            nextProgramTitle: nil
        )

        XCTAssertEqual(model.audio.value, "Muted by Panic")
        XCTAssertEqual(model.audio.status, .fail)
        XCTAssertTrue(model.isCritical)
    }

    func testStatusBarSummarizesSpeakerAndBGMTakeoverInsideAudio() {
        let speakerModel = LiveStatusBarModel.make(
            snapshot: snapshot(speaker: true),
            nextProgramTitle: nil
        )
        let takeoverModel = LiveStatusBarModel.make(
            snapshot: snapshot(bgmTakeover: true),
            nextProgramTitle: nil
        )

        XCTAssertEqual(speakerModel.audio.value, "Speaker")
        XCTAssertEqual(speakerModel.audio.status, .warn)
        XCTAssertEqual(takeoverModel.audio.value, "BGM Takeover")
        XCTAssertEqual(takeoverModel.audio.status, .warn)
    }

    func testStatusBarTruncatesCurrentAndNextDisplayButKeepsFullAccessibilityValue() {
        let longCurrent = "Opening Video With Very Long Client-Specific Title"
        let longNext = "Awards Segment With Extra Long Sponsor Title"
        let model = LiveStatusBarModel.make(
            snapshot: snapshot(currentTitle: longCurrent),
            nextProgramTitle: longNext
        )

        XCTAssertLessThanOrEqual(model.current.value.count, 24)
        XCTAssertLessThanOrEqual(model.next.value.count, 24)
        XCTAssertEqual(model.current.accessibilityValue, "\(longCurrent) · Media")
        XCTAssertEqual(model.next.accessibilityValue, longNext)
    }

    func testStatusBarItemsExposeStableLayoutRoles() {
        let model = LiveStatusBarModel.make(
            snapshot: snapshot(currentTitle: "Opening"),
            nextProgramTitle: "Awards"
        )

        XCTAssertEqual(model.projection.layoutRole, .compact)
        XCTAssertEqual(model.current.layoutRole, .primary)
        XCTAssertEqual(model.next.layoutRole, .flexible)
        XCTAssertEqual(model.audio.layoutRole, .compact)
        XCTAssertEqual(model.current.layoutRole.maxWidth, 260)
        XCTAssertEqual(model.next.layoutRole.maxWidth, 220)
    }

    func testPreflightButtonStatusMapping() {
        XCTAssertEqual(PreflightButtonModel.make(summary: summary(.pass)).status, .ready)
        XCTAssertEqual(PreflightButtonModel.make(summary: summary(.warn)).status, .warn)
        XCTAssertEqual(PreflightButtonModel.make(summary: summary(.fail)).status, .fail)
        XCTAssertEqual(PreflightButtonModel.make(summary: summary(.warn)).value, "1 Warn")
        XCTAssertEqual(PreflightButtonModel.make(summary: summary(.fail)).value, "1 Fail")
    }

    private func summary(_ status: LivePreflightStatus) -> LivePreflightSummary {
        switch status {
        case .pass:
            return LivePreflightSummary(status: .pass, title: "Ready", message: "", passCount: 1, warnCount: 0, failCount: 0)
        case .warn:
            return LivePreflightSummary(status: .warn, title: "Needs review", message: "", passCount: 1, warnCount: 1, failCount: 0)
        case .fail:
            return LivePreflightSummary(status: .fail, title: "Not ready", message: "", passCount: 1, warnCount: 0, failCount: 1)
        }
    }
}
