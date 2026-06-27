import XCTest
@testable import LiveSwitcher

final class PreflightReviewModelTests: XCTestCase {
    func testNeedsAttentionFiltersPassesAndOrdersFailBeforeWarn() {
        let checks = [
            check(id: "audio.warn", group: .audio, status: .warn),
            check(id: "display.pass", group: .display, status: .pass),
            check(id: "controls.fail", group: .controls, status: .fail),
            check(id: "playback.warn", group: .playback, status: .warn)
        ]

        let model = PreflightReviewModel.make(checks: checks, mode: .needsAttention)

        XCTAssertEqual(model.checks.map(\.id), ["controls.fail", "audio.warn", "playback.warn"])
        XCTAssertEqual(model.rowCountText, "3 项")
        XCTAssertEqual(model.sections.map(\.group), [.audio, .playback, .controls])
        XCTAssertEqual(model.sections.flatMap(\.checks).map(\.id), ["audio.warn", "playback.warn", "controls.fail"])
    }

    func testAllChecksIncludesPassRowsAfterRiskRows() {
        let checks = [
            check(id: "playback.pass", group: .playback, status: .pass),
            check(id: "audio.warn", group: .audio, status: .warn),
            check(id: "display.fail", group: .display, status: .fail)
        ]

        let model = PreflightReviewModel.make(checks: checks, mode: .allChecks)

        XCTAssertEqual(model.checks.map(\.id), ["display.fail", "audio.warn", "playback.pass"])
        XCTAssertEqual(model.rowCountText, "3 项")
        XCTAssertFalse(model.isEmpty)
    }

    func testReadyAttentionModelUsesReadyEmptyCopy() {
        let model = PreflightReviewModel.make(
            checks: [check(id: "display.pass", group: .display, status: .pass)],
            mode: .needsAttention
        )

        XCTAssertTrue(model.isEmpty)
        XCTAssertEqual(model.emptyTitle, "没有需要处理的项目")
        XCTAssertEqual(model.emptyMessage, "如需查看通过项，请切换到全部检查。")
        XCTAssertEqual(model.rowCountText, "0 项")
    }

    func testLiveSafetyCockpitUsesSharedAttentionReview() {
        let checks = [
            check(id: "display.pass", group: .display, status: .pass),
            check(id: "audio.warn", group: .audio, status: .warn),
            check(id: "controls.fail", group: .controls, status: .fail)
        ]

        let cockpit = LiveSafetyCockpit.make(
            snapshot: readySnapshot(),
            checks: checks,
            events: []
        )

        XCTAssertEqual(cockpit.attentionReview.checks.map(\.id), ["controls.fail", "audio.warn"])
        XCTAssertEqual(cockpit.attentionReview.rowCountText, "2 项")
    }

    func testPopoverAndCockpitSourceUseSharedReviewModel() throws {
        let popover = try sourceText("Views/Support/PreflightPopoverView.swift")
        let cockpit = try sourceText("Views/Support/SafetyCockpitStatusGrid.swift")

        XCTAssertTrue(popover.contains("PreflightReviewModel.make("))
        XCTAssertFalse(popover.contains("LivePreflightCheck.attentionChecks(from: viewModel.livePreflightChecks)"))
        XCTAssertTrue(cockpit.contains("cockpit.attentionReview"))
        XCTAssertFalse(cockpit.contains("priorityChecks.filter { $0.status != .pass }"))
    }

    private func check(
        id: String,
        group: LivePreflightGroup,
        status: LivePreflightStatus
    ) -> LivePreflightCheck {
        LivePreflightCheck(
            id: id,
            group: group,
            status: status,
            title: id,
            message: "message"
        )
    }

    private func readySnapshot() -> LivePreflightSnapshot {
        LivePreflightSnapshot(
            appVersion: "0.4.0",
            hasExternalDisplay: true,
            isBroadcasting: true,
            broadcastSafetyNotice: nil,
            programItemCount: 1,
            currentProgramTitle: "Opening",
            currentProgramSource: "Media",
            bgmItemCount: 1,
            isBGMPlaying: false,
            isBGMAudioTakeoverActive: false,
            isSpeakerMode: false,
            isPanicMode: false,
            isPageInterceptEnabled: false,
            activeOverlayCount: 0,
            wallpaperCount: 1,
            autoPlayNextVideoOnEnd: false,
            effectiveMediaVolume: 0.5,
            effectiveBGMVolume: 0.5
        )
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
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
