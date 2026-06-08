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
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift"
        )

        XCTAssertFalse(source.contains(".programActivation"))
        XCTAssertFalse(LiveRuntimeBridgeMode.programSelectionOwned.owns(.automation))
        XCTAssertFalse(LiveRuntimeBridgeMode.programSelectionOwned.owns(.panic))
    }

    func testProductionEnvironmentFactoryIsProgramSelectionOwning() {
        XCTAssertEqual(
            LiveRuntimeEnvironment.productionProgramSelectionOwning().bridgeMode,
            .programSelectionOwned
        )
    }

    func testProductionViewModelRuntimeBridgeModeIsProgramSelectionOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .programSelectionOwned)
    }

    func testProductionConnectedPortsRemainProgramQueueOwnedSet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .audioRouting, .imageAssets, .persistence]
        )
    }
}
