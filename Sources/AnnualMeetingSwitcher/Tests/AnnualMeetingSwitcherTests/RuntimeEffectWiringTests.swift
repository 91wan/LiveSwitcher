import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeEffectWiringTests: XCTestCase {
    func testProductionConnectedPortsExactlyMatchAutomationNoticeOwnedSet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .projection, .ppt, .automationNotice, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testProductionViewModelRuntimeBridgeModeIsAutomationNoticeOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .automationNoticeOwned)
    }

    func testProductionRuntimeWiresPPTProjectionMediaBGMAndAudioPorts() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.ppt))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.projection))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.media))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.bgm))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.audioRouting))
    }

    func testProductionRuntimeWiresBGMTimerPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.bgmTimer))
    }

    func testProductionRuntimeKeepsBGMFadeOutBehindBGMPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.bgm))
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.audioRouting))
    }

    func testProductionRuntimeWiresAutomationNoticeButNotAutomationPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let connected = viewModel.runtimeConnectedPortKinds

        XCTAssertTrue(connected.contains(.automationNotice))
        XCTAssertFalse(connected.contains(.automation))
        XCTAssertFalse(connected.contains(.support))
    }

    func testPPTHardeningKeepsRuntimeBoundaryBeforeAutomationMigration() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let connected = viewModel.runtimeConnectedPortKinds

        XCTAssertTrue(connected.contains(.projection))
        XCTAssertTrue(connected.contains(.ppt))
        XCTAssertFalse(connected.contains(.automation))
        XCTAssertFalse(connected.contains(.support))
    }

    func testCustomEffectRunnerReportsInjectedPorts() {
        let runner = LiveRuntimeEffectRunner(
            recordsOnly: false,
            audioRouting: RuntimeEffectWiringAudioPort(),
            persistence: RuntimeEffectWiringPersistencePort()
        )

        XCTAssertEqual(runner.connectedPortKinds, [.audioRouting, .persistence])
    }

    func testPersistencePortDoesNotImplyBGMOwningBridgeMode() {
        let runner = LiveRuntimeEffectRunner(
            recordsOnly: false,
            persistence: RuntimeEffectWiringPersistencePort()
        )
        let store = LiveRuntimeStore(
            effectRunner: runner,
            environment: .productionAudioOwned()
        )

        XCTAssertEqual(store.connectedPortKinds, [.persistence])
        XCTAssertEqual(store.bridgeMode, .audioOwned)
    }
}

private final class RuntimeEffectWiringAudioPort: AudioRoutingPort {
    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {}
}

private final class RuntimeEffectWiringPersistencePort: PersistencePort {
    func save() {}
}
