import XCTest
@testable import LiveSwitcher

final class RuntimeFacadeSyncPolicyTests: XCTestCase {
    func testAudioInputActionsDoNotDispatchExtraAudioInputs() {
        for action in audioInputActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).dispatchAudioInputsChanged, action.redactedName)
        }
    }

    func testMediaAndBGMCallbacksDoNotDispatchExtraAudioInputs() {
        for action in [
            LiveRuntimeAction.mediaPlaybackChanged(isPlaying: true, generation: 1),
            .mediaReachedEnd(generation: 1),
            .bgmPlaybackChanged(isPlaying: true, generation: 2),
            .bgmReachedEnd(generation: 2),
            .bgmFailed(reason: "decode", generation: 2)
        ] {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).dispatchAudioInputsChanged, action.redactedName)
        }
    }

    func testProgramAndProjectionActionsDispatchAudioInputsBeforeRuntime() {
        for action in [
            LiveRuntimeAction.operatorSelectedProgram(UUID()),
            .operatorSelectedDetachedProgram(ProgramItem(title: "Detached")),
            .operatorToggledProjection,
            .projectionExternalDisplayAvailable
        ] {
            XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: action).dispatchAudioInputsChanged, action.redactedName)
        }
    }

    func testBGMActionsSyncBGMFacade() {
        for action in [
            LiveRuntimeAction.operatorSelectedBGM(UUID()),
            .operatorStoppedBGM,
            .operatorSelectedNextBGM,
            .operatorSelectedPreviousBGM,
            .operatorSelectedBGMPlayMode(.loopAll),
            .bgmPrepared(id: UUID(), generation: 1),
            .bgmPlaybackChanged(isPlaying: true, generation: 1),
            .bgmReachedEnd(generation: 1),
            .bgmFailed(reason: "decode", generation: 1),
            .bgmProgressUpdated(time: 1, duration: 10, generation: 1)
        ] {
            XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: action).syncBGM, action.redactedName)
        }
    }

    func testProjectionActionsSyncProjectionFacade() {
        for action in [
            LiveRuntimeAction.operatorToggledProjection,
            .projectionStartFailed(reason: .noTargetScreen),
            .projectionExternalDisplayLost,
            .projectionExternalDisplayAvailable,
            .projectionExternalDisplayUnavailable
        ] {
            XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: action).syncProjection, action.redactedName)
        }
    }

    func testPPTActionsSyncPPTFacade() {
        for action in [
            LiveRuntimeAction.operatorSetPPTMode(true, source: .programmatic),
            .operatorToggledPPTMode(source: .programmatic),
            .pptEventTapStarted,
            .pptEventTapFailed(reason: "permission"),
            .pptEventTapStopped(reason: .operatorDisabled)
        ] {
            XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: action).syncPPT, action.redactedName)
        }
    }

    func testAutomationNoticeActionsSyncAutomationNoticeFacade() {
        for action in [
            LiveRuntimeAction.automationFailed(action: "keynote.next-slide", sanitizedMessage: "executionFailed"),
            .automationNoticeRequested(action: "keynote.next-slide"),
            .automationNoticeExpired(UUID()),
            .automationNoticeDismissed
        ] {
            XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: action).syncAutomationNotice, action.redactedName)
        }
    }

    func testSupportEventRecordedSyncsSupportFacade() {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 1),
            kind: .appleScriptFailed,
            detail: "action=keynote.next-slide,error=executionFailed"
        )

        XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: .supportEventRecorded(event)).syncSupport)
    }

    func testPresentationQueryActionsDoNotDispatchAudioInputs() {
        for action in presentationQueryActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).dispatchAudioInputsChanged, action.redactedName)
        }
    }

    func testPresentationQueryActionsDoNotSyncUnrelatedFacades() {
        for action in presentationQueryActions {
            let options = LiveRuntimeFacadeSyncPolicy.options(for: action)

            XCTAssertFalse(options.syncBGM, action.redactedName)
            XCTAssertFalse(options.syncProjection, action.redactedName)
            XCTAssertFalse(options.syncPPT, action.redactedName)
            XCTAssertFalse(options.syncAutomationNotice, action.redactedName)
            XCTAssertFalse(options.syncSupport, action.redactedName)
        }
    }

    func testAutomationFailedStillSyncsAutomationNoticeFacade() {
        let options = LiveRuntimeFacadeSyncPolicy.options(for: .automationFailed(
            action: "keynote.scan.windows",
            sanitizedMessage: "permissionDenied"
        ))

        XCTAssertTrue(options.syncAutomationNotice)
    }

    func testPolicyMatchesPreviousViewModelBehaviorForKnownActions() {
        XCTAssertEqual(
            LiveRuntimeFacadeSyncPolicy.options(for: .operatorSelectedProgram(UUID())),
            LiveRuntimeFacadeSyncOptions(
                dispatchAudioInputsChanged: true,
                syncBGM: false,
                syncProjection: false,
                syncPPT: false,
                syncAutomationNotice: false,
                syncSupport: false,
                syncProgramQueue: false,
                syncCurrentProgram: true
            )
        )
        XCTAssertEqual(
            LiveRuntimeFacadeSyncPolicy.options(for: .operatorSelectedBGM(UUID())),
            LiveRuntimeFacadeSyncOptions(
                dispatchAudioInputsChanged: true,
                syncBGM: true,
                syncProjection: false,
                syncPPT: false,
                syncAutomationNotice: false,
                syncSupport: false,
                syncProgramQueue: false,
                syncCurrentProgram: false
            )
        )
        XCTAssertEqual(
            LiveRuntimeFacadeSyncPolicy.options(for: .facadeAudioInputsChanged(audioSnapshot)),
            LiveRuntimeFacadeSyncOptions(
                dispatchAudioInputsChanged: false,
                syncBGM: false,
                syncProjection: false,
                syncPPT: false,
                syncAutomationNotice: false,
                syncSupport: false,
                syncProgramQueue: false,
                syncCurrentProgram: false
            )
        )
    }

    private var audioInputActions: [LiveRuntimeAction] {
        [
            .operatorSelectedAudioStrategy(.mixed),
            .operatorChangedMasterVolume(0.8),
            .operatorChangedMediaVolume(0.7),
            .operatorChangedBGMVolume(0.6),
            .operatorChangedMasterMute(true),
            .operatorChangedMediaMute(true),
            .operatorChangedBGMMute(true),
            .operatorChangedBGMTakeover(true),
            .operatorToggledSpeakerMode,
            .operatorSetSpeakerMode(true),
            .mediaPlaybackChanged(isPlaying: true, generation: 1),
            .mediaReachedEnd(generation: 1),
            .bgmPlaybackChanged(isPlaying: true, generation: 1),
            .bgmReachedEnd(generation: 1),
            .bgmFailed(reason: "decode", generation: 1),
            .operatorPausedBGMForPanic(generation: 1),
            .operatorResumedBGMAfterPanic(generation: 1),
            .facadeAudioInputsChanged(audioSnapshot)
        ]
    }

    private var audioSnapshot: AudioFacadeSnapshot {
        AudioFacadeSnapshot(
            masterVolume: 1,
            mediaVolume: 1,
            bgmVolume: 1,
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

    private var presentationQueryActions: [LiveRuntimeAction] {
        let id = UUID()
        return [
            .operatorRequestedPresentationQuery(id: id),
            .presentationQueryCompleted(id: id, result: .empty),
            .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied"),
            .presentationQueryResultConsumed(id: id)
        ]
    }
}
