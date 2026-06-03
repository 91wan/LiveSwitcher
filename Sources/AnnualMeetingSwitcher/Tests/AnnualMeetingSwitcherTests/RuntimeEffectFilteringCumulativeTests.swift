import XCTest
@testable import LiveSwitcher

final class RuntimeEffectFilteringCumulativeTests: XCTestCase {
    func testBGMPlaybackEffectsRequireBGMOwnedDomainBeforeMigration() {
        let item = bgmItem()

        [
            LiveRuntimeEffect.prepareBGM(item, generation: 1),
            .playBGM(generation: 1),
            .pauseBGM(generation: 1),
            .stopBGM(fade: 0.5, generation: 1),
            .setBGMVolume(0.4, fade: 0.2, generation: 1),
            .startBGMTimer(generation: 1),
            .stopBGMTimer(generation: 1)
        ].forEach { effect in
            XCTAssertEqual(effect.requiredBridgeDomain, .bgm)
        }
    }

    func testMediaAndBGMEffectDomainsStaySeparated() {
        let mediaURL = URL(fileURLWithPath: "/tmp/runtime-effect-domain-video.mp4")
        let bgm = bgmItem()

        XCTAssertEqual(LiveRuntimeEffect.loadMedia(mediaURL, generation: 1).requiredBridgeDomain, .media)
        XCTAssertEqual(LiveRuntimeEffect.playMedia(generation: 1).requiredBridgeDomain, .media)
        XCTAssertEqual(LiveRuntimeEffect.prepareBGM(bgm, generation: 1).requiredBridgeDomain, .bgm)
        XCTAssertEqual(LiveRuntimeEffect.saveBGMPlayMode(.loopOne).requiredBridgeDomain, .audio)
    }

    func testBGMOwningModeStillAllowsMediaEffects() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = reduce(state, .operatorSelectedProgram(item.id), bridgeMode: .bgmOwned)

        XCTAssertTrue(mutation.effects.contains(.loadMedia(item.sourceURL!, generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: 1)))
    }

    func testProjectionOwningModeStillAllowsMediaAndBGMEffects() {
        let media = mediaProgram()
        let bgm = bgmItem()
        var state = LiveRuntimeState()
        state.program.items = [media]
        state.bgm.items = [bgm]

        let mediaMutation = reduce(state, .operatorSelectedProgram(media.id), bridgeMode: .projectionOwned)
        let bgmMutation = reduce(state, .operatorSelectedBGM(bgm.id), bridgeMode: .projectionOwned)

        XCTAssertTrue(mediaMutation.effects.contains(.loadMedia(media.sourceURL!, generation: 1)))
        XCTAssertTrue(bgmMutation.effects.contains(.prepareBGM(bgm, generation: 1)))
        XCTAssertTrue(bgmMutation.effects.contains(.startBGMTimer(generation: 1)))
    }

    func testBGMOwningModeBlocksProjectionEffects() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true

        let mutation = reduce(state, .operatorToggledProjection, bridgeMode: .bgmOwned)

        XCTAssertFalse(mutation.effects.contains(.startProjection))
        XCTAssertFalse(mutation.effects.contains(.showOutputWindow))
    }

    func testProjectionOwningModeBlocksPPTAutomationAndSupportEffects() {
        let support = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 10),
            kind: .projectionStarted,
            detail: "source=test"
        )

        [
            reduce(.pptEventTapStarted, bridgeMode: .projectionOwned),
            reduce(.automationNoticeRequested(action: "keynote.open"), bridgeMode: .projectionOwned),
            reduce(.supportEventRecorded(support), bridgeMode: .projectionOwned)
        ].forEach { mutation in
            XCTAssertFalse(mutation.effects.contains(.startPPTEventTap))
            XCTAssertFalse(mutation.effects.contains { effect in
                if case .showAutomationNotice = effect { return true }
                return false
            })
            XCTAssertFalse(mutation.effects.contains(.recordSupportEvent(support)))
        }
    }

    func testMediaOwnedBlocksBGMEffects() {
        let bgm = bgmItem()
        var state = LiveRuntimeState()
        state.bgm.items = [bgm]

        let mutation = reduce(state, .operatorSelectedBGM(bgm.id), bridgeMode: .mediaOwned)

        XCTAssertFalse(mutation.effects.contains(.prepareBGM(bgm, generation: 1)))
        XCTAssertFalse(mutation.effects.contains(.startBGMTimer(generation: 1)))
    }

    func testMediaOwnedAllowsMediaEffects() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = reduce(state, .operatorSelectedProgram(item.id), bridgeMode: .mediaOwned)

        XCTAssertTrue(mutation.effects.contains(.loadMedia(item.sourceURL!, generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: 1)))
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action, bridgeMode: bridgeMode)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
    }

    private func mediaProgram() -> ProgramItem {
        ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/runtime-cumulative-video.mp4")
        )
    }

    private func bgmItem() -> BGMItem {
        BGMItem(title: "BGM", url: URL(fileURLWithPath: "/tmp/runtime-cumulative-bgm.mp3"))
    }
}
