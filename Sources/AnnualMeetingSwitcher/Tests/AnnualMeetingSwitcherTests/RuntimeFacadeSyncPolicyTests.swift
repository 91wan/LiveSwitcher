import XCTest
@testable import LiveSwitcher

final class RuntimeFacadeSyncPolicyTests: XCTestCase {
    func testFacadeSyncOptionsMatrix() {
        for testCase in cases {
            XCTAssertEqual(
                LiveRuntimeFacadeSyncPolicy.options(for: testCase.action),
                testCase.expected,
                testCase.name
            )
        }
    }

    private var cases: [Case] {
        let programID = UUID()
        let queryID = UUID()
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 1),
            kind: .appleScriptFailed,
            detail: "action=keynote.next-slide,error=executionFailed"
        )
        return [
            Case(
                "audio input action",
                .operatorChangedMasterVolume(0.8),
                expected: options()
            ),
            Case(
                "current program selection dispatches audio and syncs current program",
                .operatorSelectedProgram(programID),
                expected: options(dispatchAudioInputsChanged: true, syncCurrentProgram: true)
            ),
            Case(
                "detached current program selection dispatches audio and syncs current program",
                .operatorSelectedDetachedProgram(ProgramItem(title: "Detached")),
                expected: options(dispatchAudioInputsChanged: true, syncCurrentProgram: true)
            ),
            Case(
                "current program clear syncs current program without audio",
                .operatorClearedCurrentProgram(reason: .operatorCleared),
                expected: options(syncCurrentProgram: true)
            ),
            Case(
                "projection toggle dispatches audio and syncs projection",
                .operatorToggledProjection,
                expected: options(dispatchAudioInputsChanged: true, syncProjection: true)
            ),
            Case(
                "projection failure dispatches audio and syncs projection",
                .projectionStartFailed(reason: .noTargetScreen),
                expected: options(dispatchAudioInputsChanged: true, syncProjection: true)
            ),
            Case(
                "projection display callback dispatches audio and syncs projection",
                .projectionExternalDisplayAvailable,
                expected: options(dispatchAudioInputsChanged: true, syncProjection: true)
            ),
            Case(
                "ppt intent syncs ppt only",
                .operatorSetPPTMode(true, source: .programmatic),
                expected: options(syncPPT: true)
            ),
            Case(
                "ppt callback syncs ppt only",
                .pptEventTapFailed(reason: "permission"),
                expected: options(syncPPT: true)
            ),
            Case(
                "automation notice request syncs automation notice only",
                .automationNoticeRequested(action: "keynote.next-slide"),
                expected: options(syncAutomationNotice: true)
            ),
            Case(
                "automation failure syncs automation notice and support",
                .automationFailed(action: "keynote.next-slide", sanitizedMessage: "executionFailed"),
                expected: options(syncAutomationNotice: true, syncSupport: true)
            ),
            Case(
                "support event syncs support only",
                .supportEventRecorded(event),
                expected: options(syncSupport: true)
            ),
            Case(
                "program queue mutation syncs program queue only",
                .operatorAddedProgramItems([ProgramItem(title: "Queued")]),
                expected: options(syncProgramQueue: true)
            ),
            Case(
                "program queue removal syncs queue and current program",
                .operatorRemovedProgramItem(programID),
                expected: options(syncProgramQueue: true, syncCurrentProgram: true)
            ),
            Case(
                "presentation query consume syncs queue and current program",
                .presentationQueryResultConsumed(id: queryID),
                expected: options(syncProgramQueue: true, syncCurrentProgram: true)
            ),
            Case(
                "bgm selection dispatches audio and syncs bgm",
                .operatorSelectedBGM(UUID()),
                expected: options(dispatchAudioInputsChanged: true, syncBGM: true)
            ),
            Case(
                "bgm library mirror syncs bgm without audio dispatch",
                .facadeBGMLibraryChanged([BGMItem(title: "Walk In", url: URL(fileURLWithPath: "/tmp/walk.mp3"))]),
                expected: options(syncBGM: true)
            ),
            Case(
                "bgm callback syncs bgm without audio dispatch",
                .bgmPlaybackChanged(isPlaying: true, generation: 1),
                expected: options(syncBGM: true)
            ),
            Case(
                "panic set syncs panic and bgm without audio dispatch",
                .operatorSetPanic(true),
                expected: options(syncBGM: true, syncPanic: true)
            ),
            Case(
                "panic delayed bgm pause syncs panic and bgm without audio dispatch",
                .panicBGMPauseDelayElapsed(generation: 2, snapshot: PanicPlaybackSnapshot(
                    currentProgramID: nil,
                    wasMediaPlaying: false,
                    currentBGMID: nil,
                    wasBGMPlaying: false
                )),
                expected: options(syncBGM: true, syncPanic: true)
            ),
            Case(
                "presentation query request has no facade sync",
                .operatorRequestedPresentationQuery(id: queryID),
                expected: options()
            ),
            Case(
                "automation command request has no facade sync",
                .automationScriptRequested(script: "tell application \"Keynote\" to activate", action: "keynote.activate"),
                expected: options()
            )
        ]
    }

    private func options(
        dispatchAudioInputsChanged: Bool = false,
        syncBGM: Bool = false,
        syncProjection: Bool = false,
        syncPPT: Bool = false,
        syncAutomationNotice: Bool = false,
        syncSupport: Bool = false,
        syncProgramQueue: Bool = false,
        syncCurrentProgram: Bool = false,
        syncPanic: Bool = false
    ) -> LiveRuntimeFacadeSyncOptions {
        LiveRuntimeFacadeSyncOptions(
            dispatchAudioInputsChanged: dispatchAudioInputsChanged,
            syncBGM: syncBGM,
            syncProjection: syncProjection,
            syncPPT: syncPPT,
            syncAutomationNotice: syncAutomationNotice,
            syncSupport: syncSupport,
            syncProgramQueue: syncProgramQueue,
            syncCurrentProgram: syncCurrentProgram,
            syncPanic: syncPanic
        )
    }
}

private struct Case {
    let name: String
    let action: LiveRuntimeAction
    let expected: LiveRuntimeFacadeSyncOptions

    init(_ name: String, _ action: LiveRuntimeAction, expected: LiveRuntimeFacadeSyncOptions) {
        self.name = name
        self.action = action
        self.expected = expected
    }
}
