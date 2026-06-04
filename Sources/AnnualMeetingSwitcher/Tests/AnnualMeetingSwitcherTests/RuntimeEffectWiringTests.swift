import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeEffectWiringTests: XCTestCase {
    func testProductionConnectedPortsExactlyMatchPPTOwnedSet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .projection, .ppt, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testProductionViewModelRuntimeBridgeModeIsPPTOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .pptOwned)
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

    func testProductionRuntimeDoesNotWireAutomationNoticeOrSupport() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let connected = viewModel.runtimeConnectedPortKinds

        [
            .automation,
            .automationNotice,
            .support
        ].forEach { kind in
            XCTAssertFalse(connected.contains(kind), "\(kind.rawValue) should not be considered production-migrated.")
        }
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
