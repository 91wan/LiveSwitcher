import XCTest
@testable import LiveSwitcher

final class LiveRuntimeStatusModelTests: XCTestCase {
    func testRuntimeStatusLimitsExceptionChipsAndSummarizesOverflow() {
        let checks = (0..<6).map { index in
            LivePreflightCheck(
                id: "fail.\(index)",
                group: .display,
                status: .fail,
                title: "Fail \(index)",
                message: "Blocking issue"
            )
        } + (0..<3).map { index in
            LivePreflightCheck(
                id: "warn.\(index)",
                group: .audio,
                status: .warn,
                title: "Warn \(index)",
                message: "Warning issue"
            )
        }

        let model = LiveRuntimeStatusModel.make(
            checks: checks,
            snapshot: .fixture(
                hasExternalDisplay: false,
                isBroadcasting: false,
                currentProgramTitle: nil,
                wallpaperCount: 0,
                effectiveMediaVolume: 0,
                effectiveBGMVolume: 0
            )
        )

        XCTAssertEqual(model.chips.map(\.text), [
            "故障 · Fail 0",
            "故障 · Fail 1",
            "警告 · Warn 0",
            "+ 4 故障 · 2 警告",
            "待机 · 当前: 无节目 · 0 信号源"
        ])
        XCTAssertEqual(model.chips[3].kind, .fail)
        XCTAssertLessThanOrEqual(model.chips.count, 5)
    }

    func testRuntimeStatusOverflowUsesWarnWhenOnlyWarningsAreDropped() {
        let checks = (0..<4).map { index in
            LivePreflightCheck(
                id: "warn.\(index)",
                group: .audio,
                status: .warn,
                title: "Warn \(index)",
                message: "Warning issue"
            )
        }

        let model = LiveRuntimeStatusModel.make(
            checks: checks,
            snapshot: .fixture(
                hasExternalDisplay: true,
                isBroadcasting: false,
                currentProgramTitle: "Opening",
                wallpaperCount: 1,
                effectiveMediaVolume: 0.5,
                effectiveBGMVolume: 0.4
            )
        )

        XCTAssertEqual(model.chips.map(\.text), [
            "警告 · Warn 0",
            "+ 3 警告",
            "待机 · 当前: Opening · 1 信号源"
        ])
        XCTAssertEqual(model.chips[1].kind, .warn)
    }
}

private extension LivePreflightSnapshot {
    static func fixture(
        hasExternalDisplay: Bool,
        isBroadcasting: Bool,
        currentProgramTitle: String?,
        wallpaperCount: Int,
        effectiveMediaVolume: Float,
        effectiveBGMVolume: Float
    ) -> LivePreflightSnapshot {
        LivePreflightSnapshot(
            appVersion: "0.0.0",
            hasExternalDisplay: hasExternalDisplay,
            isBroadcasting: isBroadcasting,
            broadcastSafetyNotice: nil,
            programItemCount: currentProgramTitle == nil ? 0 : 1,
            currentProgramTitle: currentProgramTitle,
            currentProgramSource: currentProgramTitle == nil ? nil : "Media",
            bgmItemCount: 1,
            isBGMPlaying: false,
            isBGMAudioTakeoverActive: false,
            isSpeakerMode: false,
            isPanicMode: false,
            isPageInterceptEnabled: false,
            activeOverlayCount: 0,
            activeOverlayKinds: [],
            countdownRemainingSeconds: nil,
            wallpaperCount: wallpaperCount,
            autoPlayNextVideoOnEnd: false,
            effectiveMediaVolume: effectiveMediaVolume,
            effectiveBGMVolume: effectiveBGMVolume
        )
    }
}
