import Foundation
import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeTimelineTests: XCTestCase {
    func testPanicTimelinePausesAndRestoresOnlySameMediaAndBGM() {
        let video = program("Video", kind: "VIDEO", url: fixtureURL("video.mp4"))
        let bgm = bgm("Walk In")
        let store = LiveRuntimeStore(
            initialState: .fixture(
                programs: [video],
                bgmItems: [bgm],
                currentProgramID: video.id,
                currentBGMID: bgm.id,
                mediaURL: video.sourceURL,
                mediaPlaying: true,
                bgmPlaying: true
            ),
            effectRunner: .recording(),
            environment: .fullRuntimeForTests()
        )

        store.dispatch(.operatorToggledPanic)

        XCTAssertTrue(store.state.panic.isActive)
        XCTAssertFalse(store.state.media.isPlaying)
        XCTAssertTrue(store.state.bgm.isPlaying)
        XCTAssertEqual(store.state.audio.effectiveMedia, 0)
        XCTAssertEqual(store.state.audio.effectiveBGM, 0)
        XCTAssertTrue(store.recordedEffects.contains(.pauseMedia(generation: store.state.media.generation)))
        XCTAssertTrue(store.recordedEffects.contains { effect in
            if case .schedulePanicBGMPause = effect { return true }
            return false
        })
        XCTAssertFalse(store.recordedEffects.contains(.pauseBGM(generation: store.state.bgm.generation)))

        store.dispatch(.operatorToggledPanic)

        XCTAssertFalse(store.state.panic.isActive)
        XCTAssertTrue(store.state.media.isPlaying)
        XCTAssertTrue(store.state.bgm.isPlaying)
        XCTAssertTrue(store.recordedEffects.contains(.playMedia(generation: store.state.media.generation)))
        XCTAssertTrue(store.recordedEffects.contains(.playBGM(generation: store.state.bgm.generation)))
    }

    func testBGMRapidSwitchTimelineIgnoresStalePlaybackCallbacks() {
        let a = bgm("A")
        let b = bgm("B")
        let c = bgm("C")
        let store = LiveRuntimeStore(
            initialState: .fixture(bgmItems: [a, b, c]),
            effectRunner: .recording(),
            environment: .fullRuntimeForTests()
        )

        store.dispatch(.operatorSelectedBGM(a.id))
        let generationA = store.state.bgm.generation
        store.dispatch(.operatorSelectedBGM(b.id))
        let generationB = store.state.bgm.generation
        store.dispatch(.operatorSelectedBGM(c.id))
        let generationC = store.state.bgm.generation

        store.dispatch(.bgmPlaybackChanged(isPlaying: true, generation: generationA))
        store.dispatch(.bgmPlaybackChanged(isPlaying: true, generation: generationB))

        XCTAssertEqual(store.state.bgm.currentID, c.id)
        XCTAssertTrue(store.state.bgm.isPlaying)
        XCTAssertEqual(store.state.bgm.generation, generationC)
    }

    func testProjectionLostTimelineRecordsOnceAndStopsBroadcasting() {
        let store = LiveRuntimeStore(
            initialState: .fixture(hasExternalDisplay: true),
            effectRunner: .recording(),
            environment: .fullRuntimeForTests()
        )

        store.dispatch(.operatorToggledProjection)
        XCTAssertTrue(store.state.projection.isBroadcasting)

        store.dispatch(.projectionExternalDisplayLost)
        store.dispatch(.projectionExternalDisplayLost)

        XCTAssertFalse(store.state.projection.isBroadcasting)
        XCTAssertEqual(store.state.support.events.filter { $0.kind == .projectionLost }.count, 1)
        XCTAssertTrue(store.recordedEffects.contains(.stopProjection))
    }

    func testPPTFailureTimelineClearsRequestedAndDoesNotRecordEnabledSuccess() {
        let store = LiveRuntimeStore(initialState: .fixture(), effectRunner: .recording(), environment: .fullRuntimeForTests())

        store.dispatch(.operatorToggledPPTMode(source: .liveMode))
        store.dispatch(.pptEventTapFailed(reason: "tap-unavailable"))

        XCTAssertFalse(store.state.ppt.isRequested)
        XCTAssertFalse(store.state.ppt.isEventTapActive)
        XCTAssertEqual(store.state.ppt.lastFailureReason, "tap-unavailable")
        XCTAssertFalse(store.state.support.events.contains { $0.kind == .pageInterceptEnabled })
        XCTAssertTrue(store.recordedEffects.contains(.startPPTEventTap))
        XCTAssertFalse(store.recordedEffects.contains(.stopPPTEventTap(reason: .failed)))
    }

    func testAutomationFailureTimelineCreatesNoticeAndCoalescesRepeatedSupportEvents() {
        let store = LiveRuntimeStore(initialState: .fixture(), effectRunner: .recording(), environment: .fullRuntimeForTests())

        store.dispatch(.operatorToggledPanic)
        for _ in 0..<100 {
            store.dispatch(.automationFailed(action: "keynote.next-slide", sanitizedMessage: "event failed"))
        }

        XCTAssertEqual(store.state.automation.notice?.action, "keynote.next-slide")
        let automationEvents = store.state.support.events.filter { $0.kind == .appleScriptFailed }
        XCTAssertEqual(automationEvents.count, 1)
        XCTAssertTrue(automationEvents[0].detail.contains("count=100"))
        XCTAssertFalse(store.state.support.events.contains { $0.kind == .panicModeChanged })
    }

    func testProgramSwitchTimelineStopsPreviousRuntimeOwner() {
        let video = program("Video", kind: "VIDEO", url: fixtureURL("video.mp4"))
        let deck = program("Deck", kind: "KEYNOTE", url: fixtureURL("deck.key"))
        let html = program("HTML", kind: "HTML", url: fixtureURL("index.html"))
        let store = LiveRuntimeStore(
            initialState: .fixture(programs: [video, deck, html]),
            effectRunner: .recording(),
            environment: .fullRuntimeForTests()
        )

        store.dispatch(.operatorSelectedProgram(video.id))
        XCTAssertEqual(store.state.program.currentID, video.id)
        XCTAssertEqual(store.state.media.loadedURL, video.sourceURL)

        store.dispatch(.operatorSelectedProgram(deck.id))
        XCTAssertFalse(store.state.media.isPlaying)
        XCTAssertTrue(store.recordedEffects.contains(.stopMedia(generation: store.state.media.generation)))
        XCTAssertFalse(store.recordedEffects.contains(.startPPTEventTap))

        store.dispatch(.operatorSelectedProgram(html.id))
        XCTAssertEqual(store.state.program.currentID, html.id)
        XCTAssertFalse(store.recordedEffects.contains(.stopPPTEventTap(reason: .programChanged)))
    }

    func testRestartMediaTimelineRequiresExplicitRestartAfterEnd() {
        let video = program("Video", kind: "VIDEO", url: fixtureURL("video.mp4"))
        let store = LiveRuntimeStore(
            initialState: .fixture(
                programs: [video],
                currentProgramID: video.id,
                mediaURL: video.sourceURL,
                mediaPlaying: false
            ),
            effectRunner: .recording(),
            environment: .fullRuntimeForTests()
        )
        store.dispatch(.mediaReachedEnd(generation: store.state.media.generation))

        store.dispatch(.operatorToggledMediaPlayback)
        XCTAssertTrue(store.state.media.didPlayToEnd)
        XCTAssertFalse(store.recordedEffects.contains(.playMedia(generation: store.state.media.generation)))

        store.dispatch(.operatorRestartedCurrentMedia)

        XCTAssertFalse(store.state.media.didPlayToEnd)
        XCTAssertEqual(store.state.media.currentTime, 0)
        XCTAssertTrue(store.state.media.isPlaying)
        XCTAssertTrue(store.recordedEffects.contains(.restartMedia(generation: store.state.media.generation)))
    }

    func testRuntimeActionLogStoresRedactedActionNamesInsteadOfFilePaths() {
        let video = program("Video", kind: "VIDEO", url: fixtureURL("private-video.mp4"))
        let store = LiveRuntimeStore(
            initialState: .fixture(programs: [video]),
            effectRunner: .recording(),
            environment: .fullRuntimeForTests()
        )

        store.dispatch(.operatorSelectedProgram(video.id))

        XCTAssertEqual(store.actionLog.last?.actionName, "operatorSelectedProgram")
        XCTAssertFalse(store.actionLog.last?.actionName.contains("/tmp") ?? true)
        XCTAssertFalse(store.actionLog.last?.newStateSummary.contains("private-video.mp4") ?? true)
    }

    private func program(_ title: String, kind: String, url: URL) -> ProgramItem {
        ProgramItem(title: title, subtitle: kind, sourceURL: url)
    }

    private func bgm(_ title: String) -> BGMItem {
        BGMItem(title: title, url: fixtureURL("\(title).wav"), category: .warmUp)
    }

    private func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }
}

private extension LiveRuntimeState {
    static func fixture(
        programs: [ProgramItem] = [],
        bgmItems: [BGMItem] = [],
        currentProgramID: UUID? = nil,
        currentBGMID: UUID? = nil,
        mediaURL: URL? = nil,
        mediaPlaying: Bool = false,
        bgmPlaying: Bool = false,
        hasExternalDisplay: Bool = false
    ) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = programs
        state.program.currentID = currentProgramID
        state.media.loadedURL = mediaURL
        state.media.isPlaying = mediaPlaying
        state.bgm.items = bgmItems
        state.bgm.currentID = currentBGMID
        state.bgm.phase = bgmPlaying ? .playing : .selected
        state.projection.hasExternalDisplay = hasExternalDisplay
        state.audio.effectiveMedia = mediaPlaying ? 1 : 0
        state.audio.effectiveBGM = bgmPlaying ? 0.5 : 0
        return state
    }
}
