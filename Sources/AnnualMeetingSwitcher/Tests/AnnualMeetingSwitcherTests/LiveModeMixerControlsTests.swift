import XCTest
@testable import LiveSwitcher

final class LiveModeMixerControlsTests: XCTestCase {
    func testAudioMeterModelMapsMutedAndActiveLevels() {
        let muted = LiveAudioMeterModel.make(effectiveVolume: 0, isMuted: true)
        XCTAssertEqual(muted.level, 0)
        XCTAssertEqual(muted.decibelText, "-∞ dB")
        XCTAssertEqual(muted.statusKind, .muted)

        let active = LiveAudioMeterModel.make(effectiveVolume: 0.5, isMuted: false)
        XCTAssertGreaterThan(active.level, 0)
        XCTAssertLessThan(active.level, 1)
        XCTAssertEqual(active.decibelText, "-6 dB")
        XCTAssertEqual(active.statusKind, .ready)
    }

    func testCutBusModelEnablesTakeNextOnlyWhenQueueHasNextItem() {
        let current = ProgramItem(id: UUID(), title: "Opening", subtitle: "MP4")
        let next = ProgramItem(id: UUID(), title: "Awards", subtitle: "HTML")

        let noNext = LiveCutBusModel.make(programItems: [current], currentProgramItem: current)
        XCTAssertFalse(noNext.canTakeNext)
        XCTAssertNil(noNext.nextIndex)
        XCTAssertEqual(noNext.nextTitle, "No next source")

        let hasNext = LiveCutBusModel.make(programItems: [current, next], currentProgramItem: current)
        XCTAssertTrue(hasNext.canTakeNext)
        XCTAssertEqual(hasNext.nextIndex, 1)
        XCTAssertEqual(hasNext.nextTitle, "Awards")
    }

    func testRuntimeStatusModelPrioritizesPreflightExceptions() {
        var snapshot = LivePreflightSnapshot.fixture(
            hasExternalDisplay: false,
            isBroadcasting: false,
            currentProgramTitle: nil,
            wallpaperCount: 1,
            effectiveMediaVolume: 0.5,
            effectiveBGMVolume: 0.4
        )

        let fail = LiveRuntimeStatusModel.make(snapshot: snapshot)
        XCTAssertEqual(fail.kind, .fail)
        XCTAssertTrue(fail.text.contains("External Display"))

        snapshot = LivePreflightSnapshot.fixture(
            hasExternalDisplay: true,
            isBroadcasting: false,
            currentProgramTitle: "Opening",
            wallpaperCount: 1,
            effectiveMediaVolume: 0.5,
            effectiveBGMVolume: 0.4
        )
        let warn = LiveRuntimeStatusModel.make(snapshot: snapshot)
        XCTAssertEqual(warn.kind, .warn)
        XCTAssertTrue(warn.text.contains("Projection State"))

        snapshot = LivePreflightSnapshot.fixture(
            hasExternalDisplay: true,
            isBroadcasting: true,
            currentProgramTitle: "Opening",
            wallpaperCount: 1,
            effectiveMediaVolume: 0.5,
            effectiveBGMVolume: 0.4
        )
        let ready = LiveRuntimeStatusModel.make(snapshot: snapshot)
        XCTAssertEqual(ready.kind, .live)
        XCTAssertTrue(ready.text.contains("Current: Opening"))
    }

    func testRuntimeStatusModelExposesExceptionChipsAndSummaryTogether() {
        let snapshot = LivePreflightSnapshot.fixture(
            hasExternalDisplay: false,
            isBroadcasting: false,
            currentProgramTitle: nil,
            wallpaperCount: 0,
            effectiveMediaVolume: 0,
            effectiveBGMVolume: 0
        )

        let model = LiveRuntimeStatusModel.make(snapshot: snapshot)

        XCTAssertGreaterThanOrEqual(model.chips.count, 3)
        XCTAssertTrue(model.chips.contains { $0.kind == .fail && $0.text.contains("External Display") })
        XCTAssertTrue(model.chips.contains { $0.kind == .warn && $0.text.contains("Current Program") })
        XCTAssertTrue(model.chips.contains { $0.text.contains("STANDBY") && $0.text.contains("0 sources") })
    }

    @MainActor
    func testFadeToBlackDoesNotTogglePanicOrMuteAudio() {
        let suite = "FadeToBlack-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Could not create isolated defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        viewModel.isMasterAudioMuted = false
        viewModel.isMediaAudioMuted = false
        viewModel.isBGMAudioMuted = false

        viewModel.toggleFadeToBlack()

        XCTAssertTrue(viewModel.isFadeToBlackActive)
        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.isMasterAudioMuted)
        XCTAssertFalse(viewModel.isMediaAudioMuted)
        XCTAssertFalse(viewModel.isBGMAudioMuted)
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .fadeToBlackChanged })
    }

    func testLiveModeViewContainsMetersMuteButtonsAndCutBus() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("LiveAudioMeter"))
        XCTAssertTrue(source.contains("isMasterAudioMuted"))
        XCTAssertTrue(source.contains("isMediaAudioMuted"))
        XCTAssertTrue(source.contains("isBGMAudioMuted"))
        XCTAssertTrue(source.contains("viewModel.isPanicMode || viewModel.isMasterAudioMuted"))
        XCTAssertTrue(source.contains("Cut Bus"))
        XCTAssertTrue(source.contains("Take Next"))
    }

    func testCutBusUsesFadeToBlackInsteadOfPanic() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("viewModel.toggleFadeToBlack()"))
        XCTAssertTrue(source.contains("Restore from FTB"))
        XCTAssertFalse(source.contains("viewModel.togglePanicMode()"))
    }

    func testLiveModeMuteButtonsUseTransportHitTargetHeight() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertFalse(source.contains("height: 22"))
        XCTAssertTrue(source.contains("height: LiveModeLayoutMetrics.transportButtonSize"))
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
