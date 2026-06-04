import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeActionLogPolicyTests: XCTestCase {
    func testFacadeAudioInputsChangedIsNotLogged() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        runtime.dispatch(.facadeAudioInputsChanged(audioSnapshot()))

        XCTAssertFalse(LiveRuntimeActionLogPolicy.shouldLog(.facadeAudioInputsChanged(audioSnapshot())))
        XCTAssertTrue(runtime.actionLog.isEmpty)
    }

    func testBGMProgressUpdatedIsNotLogged() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        runtime.dispatch(.bgmProgressUpdated(time: 1, duration: 10, generation: 0))

        XCTAssertFalse(LiveRuntimeActionLogPolicy.shouldLog(.bgmProgressUpdated(time: 1, duration: 10, generation: 0)))
        XCTAssertTrue(runtime.actionLog.isEmpty)
    }

    func testOperatorActionsAreLogged() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        runtime.dispatch(.operatorChangedMasterVolume(0.2))

        XCTAssertTrue(LiveRuntimeActionLogPolicy.shouldLog(.operatorChangedMasterVolume(0.2)))
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorChangedMasterVolume" })
    }

    func testAutomationFailuresAreLogged() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        runtime.dispatch(.automationFailed(action: "keynote.open", sanitizedMessage: "failed"))

        XCTAssertTrue(LiveRuntimeActionLogPolicy.shouldLog(.automationFailed(action: "keynote.open", sanitizedMessage: "failed")))
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "automationFailed" })
    }

    func testSupportEventRecordedIsNotLoggedButStillWritesSupportState() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .supportOwned)
        )
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .projectionStarted,
            detail: "source=viewModel"
        )

        runtime.dispatch(.supportEventRecorded(event))

        XCTAssertFalse(LiveRuntimeActionLogPolicy.shouldLog(.supportEventRecorded(event)))
        XCTAssertTrue(runtime.actionLog.isEmpty)
        XCTAssertEqual(runtime.state.support.events, [event])
    }

    func testRepeatedSupportEventsDoNotGrowActionLog() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .supportOwned)
        )
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .projectionStarted,
            detail: "source=viewModel"
        )

        runtime.dispatch(.supportEventRecorded(event))
        runtime.dispatch(.supportEventRecorded(event))
        runtime.dispatch(.supportEventRecorded(event))

        XCTAssertTrue(runtime.actionLog.isEmpty)
        XCTAssertEqual(runtime.state.support.events.count, 3)
    }

    func testAutomationNoticeDismissalStillLogsAction() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .automationNoticeOwned)
        )

        runtime.dispatch(.automationNoticeDismissed)

        XCTAssertTrue(LiveRuntimeActionLogPolicy.shouldLog(.automationNoticeDismissed))
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "automationNoticeDismissed" })
    }

    func testProjectionLostIsLogged() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        runtime.dispatch(.projectionExternalDisplayLost)

        XCTAssertTrue(LiveRuntimeActionLogPolicy.shouldLog(.projectionExternalDisplayLost))
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "projectionExternalDisplayLost" })
    }

    private func audioSnapshot() -> AudioFacadeSnapshot {
        AudioFacadeSnapshot(
            masterVolume: 0.5,
            mediaVolume: 1,
            bgmVolume: 0.5,
            strategy: .mixed,
            isMasterMuted: false,
            isMediaMuted: false,
            isBGMMuted: false,
            isSpeakerMode: false,
            isBGMTakeoverActive: false,
            isPanicMode: false,
            isCurrentProgramMediaSource: false,
            isMediaPlaying: false,
            isBGMPlaying: false
        )
    }
}
