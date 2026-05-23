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
            isBGMAudioTakeoverActive: false,
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
        XCTAssertEqual(model.audio.value, "Media 50% / BGM 40%")
        XCTAssertTrue(model.isCritical)
    }

    func testStatusBarWarnsWhenExternalDisplayMissing() {
        let model = LiveStatusBarModel.make(
            snapshot: snapshot(hasExternalDisplay: false, currentTitle: nil, currentSource: nil),
            nextProgramTitle: nil
        )

        XCTAssertEqual(model.projection.value, "No External Display")
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

        XCTAssertEqual(model.audio.status, .muted)
        XCTAssertEqual(model.panic.value, "Active")
        XCTAssertEqual(model.panic.status, .fail)
        XCTAssertTrue(model.isCritical)
    }

    func testPreflightButtonStatusMapping() {
        XCTAssertEqual(PreflightButtonModel.make(summary: summary(.pass)).status, .ready)
        XCTAssertEqual(PreflightButtonModel.make(summary: summary(.warn)).status, .warn)
        XCTAssertEqual(PreflightButtonModel.make(summary: summary(.fail)).status, .fail)
        XCTAssertEqual(PreflightButtonModel.make(summary: summary(.warn)).value, "Review")
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
