import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramActivationMigrationReadinessTests: XCTestCase {
    func testNoProgramActivationOwnedBridgeModeYet() throws {
        let source = try runtimeStateSource()

        XCTAssertFalse(source.contains("programActivationOwned"))
    }

    func testNoProgramActivationDomainYet() throws {
        let source = try runtimeStateSource()

        XCTAssertFalse(source.contains("case programActivation"))
    }

    func testNoProgramActivationPortYet() throws {
        let ports = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift"
        )

        XCTAssertFalse(ports.contains("ProgramActivationPort"))
        XCTAssertFalse(ports.contains("programActivationPort"))
    }

    func testNoActivateProgramEffectYet() throws {
        let effect = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift"
        )

        XCTAssertFalse(effect.contains("activateProgram"))
        XCTAssertFalse(effect.contains("programActivation"))
    }

    func testNoProgramActivationCallbackActionsYet() throws {
        let action = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift"
        )

        XCTAssertFalse(action.contains("programActivationCompleted"))
        XCTAssertFalse(action.contains("programActivationFailed"))
    }

    func testProgramActivationStillViewModelOwned() throws {
        let docs = try repositorySource("docs/architecture/runtime-ownership.md")
        let normalizedDocs = docs.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        XCTAssertTrue(normalizedDocs.localizedStandardContains("Program activation/switching side effects are still ViewModel-owned"))
    }

    func testProgramActivationSideEffectsRemainViewModelOwned() throws {
        let viewModel = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift"
        )
        let activation = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(viewModel.contains("programActivationSideEffects = ProgramActivationSideEffectHandlers()"))
        XCTAssertTrue(activation.contains("programActivationSideEffects.presentKeynote"))
        XCTAssertTrue(activation.contains("programActivationSideEffects.openPPTX"))
        XCTAssertTrue(activation.contains("programActivationSideEffects.stopDeck"))
        XCTAssertTrue(activation.contains("programActivationSideEffects.presentActiveDeck"))
        XCTAssertTrue(activation.contains("programActivationSideEffects.presentInvalidDeckAlert"))
    }

    func testProgramActivationSideEffectHandlersAreNotRuntimePortsYet() throws {
        let ports = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift"
        )
        let effects = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift"
        )

        XCTAssertFalse(ports.contains("ProgramActivationSideEffectHandlers"))
        XCTAssertFalse(ports.contains("ProgramActivationPort"))
        XCTAssertFalse(effects.contains("ProgramActivationSideEffectHandlers"))
        XCTAssertFalse(effects.contains("activateProgram"))
    }

    func testProgramActivationPlannerIsPure() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ProgramActivationPlanner.swift"
        )

        for forbidden in [
            "SwitcherViewModel",
            "LiveRuntimeStore",
            "FileManager.default",
            "recordSupportEvent",
            "dispatchRuntimeFacadeAction",
            "NSAlert"
        ] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testProgramActivationExecutorLivesInViewModelExtension() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains("executeProgramActivationPlan"))
    }

    func testProgramSourceAvailabilityPolicyIsPure() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ProgramSourceAvailabilityPolicy.swift"
        )

        for forbidden in [
            "SwitcherViewModel",
            "LiveRuntimeStore",
            "FileManager.default",
            "recordSupportEvent",
            "showAutomationRuntimeNotice",
            "NSAlert"
        ] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testProgramSelectionOwnedModeDoesNotOwnProgramActivation() throws {
        let source = try runtimeStateSource()

        XCTAssertFalse(source.contains(".programActivation"))
        XCTAssertTrue(LiveRuntimeBridgeMode.programSelectionOwned.owns(.programSelection))
        XCTAssertFalse(LiveRuntimeBridgeMode.programSelectionOwned.owns(.automation))
    }

    func testProductionViewModelRuntimeBridgeModeIsProgramSelectionOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .programSelectionOwned)
    }

    func testProductionConnectedPortsRemainExplicitRuntimeSet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .audioRouting, .imageAssets, .persistence]
        )
    }

    private func runtimeStateSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift")
    }
}
