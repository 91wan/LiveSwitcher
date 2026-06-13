import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramQueueRuntimeOwnershipTests: XCTestCase {
    func testProgramQueueOwnedModeOwnsPriorDomainsAndProgramQueue() {
        let mode = LiveRuntimeBridgeMode.programQueueOwned

        for domain in [
            LiveRuntimeDomain.audio,
            .media,
            .bgm,
            .projection,
            .ppt,
            .automationNotice,
            .support,
            .automationCommand,
            .presentationQuery,
            .programQueue
        ] {
            XCTAssertTrue(mode.owns(domain), "\(domain)")
        }
    }

    func testProgramQueueOwnedModeStillOwnsImageAssetsAndPersistence() {
        let mode = LiveRuntimeBridgeMode.programQueueOwned

        XCTAssertTrue(mode.owns(.imageAssets))
        XCTAssertTrue(mode.owns(.persistence))
    }

    func testProgramQueueOwnedModeStillOwnsPresentationQuery() {
        XCTAssertTrue(LiveRuntimeBridgeMode.programQueueOwned.owns(.presentationQuery))
    }

    func testProgramQueueOwnedModeDoesNotOwnPanic() {
        XCTAssertFalse(LiveRuntimeBridgeMode.programQueueOwned.owns(.panic))
    }

    func testProductionViewModelRuntimeBridgeModeIsPanicOwned() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.runtimeBridgeMode, .panicOwned)
    }

    func testProductionConnectedPortsRemainExplicitRuntimeSet() {
        let viewModel = makeViewModel()

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .panicDelay, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]
        )
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ProgramQueueRuntimeOwnershipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }
}
