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

    func testPresentationQueryCompletedAndConsumedAreNotLogged() {
        let id = UUID()
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .presentationQueryOwned)
        )

        runtime.dispatch(.operatorRequestedPresentationQuery(id: id))
        runtime.dispatch(.presentationQueryCompleted(
            id: id,
            result: PresentationQueryResult(openFilePaths: ["/tmp/private/Opening.key"], windowNames: ["Opening.key"])
        ))
        runtime.dispatch(.presentationQueryResultConsumed(id: id))

        XCTAssertFalse(LiveRuntimeActionLogPolicy.shouldLog(.presentationQueryCompleted(id: id, result: .empty)))
        XCTAssertFalse(LiveRuntimeActionLogPolicy.shouldLog(.presentationQueryResultConsumed(id: id)))
        XCTAssertFalse(runtime.actionLog.contains { $0.actionName == "presentationQueryCompleted" })
        XCTAssertFalse(runtime.actionLog.contains { $0.actionName == "presentationQueryResultConsumed" })
        XCTAssertFalse(runtime.actionLog.contains { entry in
            entry.oldStateSummary.contains("/tmp/private")
                || entry.newStateSummary.contains("/tmp/private")
                || entry.oldStateSummary.contains("Opening.key")
                || entry.newStateSummary.contains("Opening.key")
        })
    }

    func testOperatorRequestedPresentationQueryAndFailureStillLog() {
        let id = UUID()
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .presentationQueryOwned)
        )

        runtime.dispatch(.operatorRequestedPresentationQuery(id: id))
        runtime.dispatch(.presentationQueryFailed(
            id: id,
            action: "keynote.scan.windows",
            sanitizedMessage: "permissionDenied"
        ))

        XCTAssertTrue(LiveRuntimeActionLogPolicy.shouldLog(.operatorRequestedPresentationQuery(id: id)))
        XCTAssertTrue(LiveRuntimeActionLogPolicy.shouldLog(.presentationQueryFailed(
            id: id,
            action: "keynote.scan.windows",
            sanitizedMessage: "permissionDenied"
        )))
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorRequestedPresentationQuery" })
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "presentationQueryFailed" })
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

    func testActionLogRetainsOnlyTheNewestEntriesWithinPolicyLimit() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        runtime.dispatch(.automationFailed(action: "first", sanitizedMessage: "failed"))

        for _ in 0..<LiveRuntimeActionLogPolicy.maxEntries {
            runtime.dispatch(.automationNoticeDismissed)
        }
        runtime.dispatch(.projectionExternalDisplayLost)

        XCTAssertEqual(runtime.actionLog.count, LiveRuntimeActionLogPolicy.maxEntries)
        XCTAssertFalse(runtime.actionLog.contains { $0.actionName == "automationFailed" })
        XCTAssertEqual(runtime.actionLog.first?.actionName, "automationNoticeDismissed")
        XCTAssertEqual(runtime.actionLog.last?.actionName, "projectionExternalDisplayLost")
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
