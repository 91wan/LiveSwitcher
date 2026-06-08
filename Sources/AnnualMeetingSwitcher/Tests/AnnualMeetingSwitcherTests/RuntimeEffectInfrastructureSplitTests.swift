import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeEffectInfrastructureSplitTests: XCTestCase {
    func testLiveRuntimeEffectFileContainsOnlyEffectEnumAndNoPorts() throws {
        let source = try runtimeSource("LiveRuntimeEffect.swift")

        XCTAssertTrue(source.contains("enum LiveRuntimeEffect: Equatable"))
        XCTAssertFalse(source.contains("protocol MediaPlaybackPort"))
        XCTAssertFalse(source.contains("protocol PersistencePort"))
        XCTAssertFalse(source.contains("protocol SupportEventPort"))
        XCTAssertFalse(source.contains("enum LiveRuntimeEffectPortKind"))
        XCTAssertFalse(source.contains("var requiredBridgeDomain"))
        XCTAssertFalse(source.contains("var redactedForRecording"))
    }

    func testLiveRuntimeEffectFileDoesNotContainEffectRunner() throws {
        let source = try runtimeSource("LiveRuntimeEffect.swift")

        XCTAssertFalse(source.contains("final class LiveRuntimeEffectRunner"))
        XCTAssertFalse(source.contains("func run("))
        XCTAssertFalse(source.contains("isCurrentMediaGeneration"))
        XCTAssertFalse(source.contains("isCurrentBGMGeneration"))
    }

    func testEffectPolicyLivesInEffectPolicyFile() throws {
        let source = try runtimeSource("LiveRuntimeEffect+Policy.swift")

        XCTAssertTrue(source.contains("extension LiveRuntimeEffect"))
        XCTAssertTrue(source.contains("var redactedForRecording: LiveRuntimeEffect"))
        XCTAssertTrue(source.contains("var requiredBridgeDomain: LiveRuntimeDomain"))
    }

    func testEffectPortKindLivesInOwnFile() throws {
        let source = try runtimeSource("LiveRuntimeEffectPortKind.swift")

        XCTAssertTrue(source.contains("enum LiveRuntimeEffectPortKind: String, CaseIterable"))
        XCTAssertFalse(source.contains("protocol "))
        XCTAssertFalse(source.contains("final class LiveRuntimeEffectRunner"))
    }

    func testRuntimePortProtocolsLiveInRuntimePortsFile() throws {
        let source = try runtimeSource("LiveRuntimePorts.swift")

        [
            "protocol MediaPlaybackPort",
            "protocol BGMPlaybackPort",
            "protocol ProjectionPort",
            "protocol PPTEventTapPort",
            "protocol AutomationPort",
            "protocol BGMTimerPort",
            "protocol AutomationNoticePort",
            "protocol PresentationQueryPort",
            "protocol AudioRoutingPort",
            "protocol ImageAssetPort",
            "protocol PersistencePort",
            "protocol SupportEventPort"
        ].forEach { snippet in
            XCTAssertTrue(source.contains(snippet), snippet)
        }
        XCTAssertFalse(source.contains("extension PersistencePort"))
        XCTAssertFalse(source.contains("final class LiveRuntimeEffectRunner"))
    }

    func testEffectRunnerLivesInEffectRunnerFile() throws {
        let source = try runtimeSource("LiveRuntimeEffectRunner.swift")

        XCTAssertTrue(source.contains("final class LiveRuntimeEffectRunner"))
        XCTAssertTrue(source.contains("var connectedPortKinds: Set<LiveRuntimeEffectPortKind>"))
        XCTAssertTrue(source.contains("recordedEffects.append(contentsOf: effects.map(\\.redactedForRecording))"))
        XCTAssertFalse(source.contains("protocol MediaPlaybackPort"))
        XCTAssertFalse(source.contains("enum LiveRuntimeEffect: Equatable"))
    }

    func testSwitcherRuntimePortBundleLivesInOwnFile() throws {
        let source = try runtimeSource("SwitcherRuntimePortBundle.swift")

        XCTAssertTrue(source.contains("struct SwitcherRuntimePortBundle"))
        XCTAssertTrue(source.contains("func makeEffectRunner() -> LiveRuntimeEffectRunner"))
        XCTAssertTrue(source.contains("imageAssets: imageAssetPort"))
        XCTAssertTrue(source.contains("persistence: persistencePort"))
    }

    func testLiveRuntimeClosurePortsFileDoesNotContainSwitcherRuntimePortBundle() throws {
        let source = try runtimeSource("LiveRuntimeClosurePorts.swift")

        XCTAssertFalse(source.contains("struct SwitcherRuntimePortBundle"))
        XCTAssertTrue(source.contains("final class ClosureMediaPlaybackPort"))
        XCTAssertTrue(source.contains("final class ClosurePersistencePort"))
    }

    func testClosurePortsFileContainsOnlyClosurePortAdapters() throws {
        let source = try runtimeSource("LiveRuntimeClosurePorts.swift")

        XCTAssertFalse(source.contains("enum LiveRuntimeEffect"))
        XCTAssertFalse(source.contains("var requiredBridgeDomain"))
        XCTAssertFalse(source.contains("final class LiveRuntimeEffectRunner"))
        XCTAssertFalse(source.contains("protocol MediaPlaybackPort"))
    }

    func testSwitcherRuntimePortBundleStillCreatesAllProductionPorts() {
        let runner = SwitcherRuntimePortBundle().makeEffectRunner()

        XCTAssertEqual(
            runner.connectedPortKinds,
            [.media, .bgm, .bgmTimer, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testSwitcherRuntimePortBundleConnectedPortsIncludePresentationQuerySet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .programSelectionOwned)
        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testEffectSplitHasNarrowPresentationQueryButNoBroadAutomationQuery() throws {
        let state = try runtimeSource("LiveRuntimeState.swift")
        let effect = try runtimeSource("LiveRuntimeEffect.swift")
        let ports = try runtimeSource("LiveRuntimePorts.swift")

        XCTAssertFalse(state.contains("automationQueryOwned"))
        XCTAssertFalse(state.contains("automationQuery"))
        XCTAssertTrue(state.contains("presentationQueryOwned"))
        XCTAssertTrue(effect.contains("scanPresentationQuery"))
        XCTAssertTrue(ports.contains("PresentationQueryPort"))
        XCTAssertFalse(ports.contains("AutomationQueryPort"))
    }

    private func runtimeSource(_ filename: String) throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/\(filename)")
    }
}
