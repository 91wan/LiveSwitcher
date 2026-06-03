import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeEffectWiringTests: XCTestCase {
    func testProductionRuntimeWiringDeclaresConnectedPorts() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testProductionViewModelRuntimeBridgeModeIsMediaOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .mediaOwned)
    }

    func testProductionRuntimeWiresMediaAndAudioPorts() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.media))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.audioRouting))
    }

    func testProductionRuntimeDoesNotWireBGMProjectionPPTAutomationSupport() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let connected = viewModel.runtimeConnectedPortKinds

        [
            LiveRuntimeEffectPortKind.bgm,
            .projection,
            .ppt,
            .automation,
            .bgmTimer,
            .automationNotice,
            .support
        ].forEach { kind in
            XCTAssertFalse(connected.contains(kind), "\(kind.rawValue) should not be considered production-migrated.")
        }
    }

    func testCustomEffectRunnerReportsInjectedPorts() {
        let runner = LiveRuntimeEffectRunner(
            recordsOnly: false,
            audioRouting: RuntimeEffectWiringAudioPort(),
            persistence: RuntimeEffectWiringPersistencePort()
        )

        XCTAssertEqual(runner.connectedPortKinds, [.audioRouting, .persistence])
    }
}

private final class RuntimeEffectWiringAudioPort: AudioRoutingPort {
    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {}
}

private final class RuntimeEffectWiringPersistencePort: PersistencePort {
    func save() {}
}
