import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramSelectionRuntimeOwnershipTests: XCTestCase {
    func testBridgeModeCasesIncludeProgramSelectionAfterProgramQueue() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.allCases,
            [
                .recordingOnly,
                .audioOwned,
                .mediaOwned,
                .bgmOwned,
                .projectionOwned,
                .pptOwned,
                .automationNoticeOwned,
                .supportOwned,
                .automationCommandOwned,
                .presentationQueryOwned,
                .programQueueOwned,
                .programSelectionOwned,
                .programActivationOwned,
                .panicOwned,
                .fullRuntime
            ]
        )
    }

    func testProgramSelectionDomainIsExplicit() {
        XCTAssertTrue(LiveRuntimeDomain.allCases.contains(.programSelection))
    }

    func testProgramQueueOwnedDoesNotOwnProgramSelection() {
        XCTAssertFalse(LiveRuntimeBridgeMode.programQueueOwned.owns(.programSelection))
    }

    func testProgramSelectionOwnedOwnsPriorDomainsAndSelection() {
        let mode = LiveRuntimeBridgeMode.programSelectionOwned

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
            .programQueue,
            .programSelection,
            .imageAssets,
            .persistence
        ] {
            XCTAssertTrue(mode.owns(domain), "\(domain)")
        }
    }

    func testProgramSelectionOwnedStillDoesNotOwnActivationOrBroadAutomation() throws {
        XCTAssertFalse(LiveRuntimeBridgeMode.programSelectionOwned.owns(.programActivation))
        XCTAssertFalse(LiveRuntimeBridgeMode.programSelectionOwned.owns(.automation))
        XCTAssertFalse(LiveRuntimeBridgeMode.programSelectionOwned.owns(.panic))
    }

    func testProductionEnvironmentFactoryIsProgramSelectionOwning() {
        XCTAssertEqual(
            LiveRuntimeEnvironment.productionProgramSelectionOwning().bridgeMode,
            .programSelectionOwned
        )
    }

    func testProductionViewModelRuntimeBridgeModeIsPanicOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .panicOwned)
    }

    func testProductionConnectedPortsRemainPanicOwnedSet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .panicDelay, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]
        )
    }
}
