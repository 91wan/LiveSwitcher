import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramActivationMigrationReadinessTests: XCTestCase {
    func testProgramActivationOwnedBridgeModeExists() throws {
        let source = try runtimeStateSource()

        XCTAssertTrue(source.contains("programActivationOwned"))
    }

    func testProgramActivationDomainExists() throws {
        let source = try runtimeStateSource()

        XCTAssertTrue(source.contains("case programActivation"))
    }

    func testProgramActivationPortExists() throws {
        let ports = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift"
        )

        XCTAssertTrue(ports.contains("ProgramActivationPort"))
    }

    func testNoActivateProgramEffectYet() throws {
        let effect = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift"
        )

        XCTAssertFalse(effect.contains("activateProgram"))
        XCTAssertTrue(effect.contains("executeProgramActivation"))
    }

    func testNoProgramActivationCallbackActionsYet() throws {
        let action = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift"
        )

        XCTAssertTrue(action.contains("programActivationCompleted"))
        XCTAssertFalse(action.contains("programActivationFailed"))
    }

    func testProgramActivationStillViewModelOwned() throws {
        let docs = try repositorySource("docs/architecture/runtime-ownership.md")
        let normalizedDocs = docs.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        XCTAssertTrue(normalizedDocs.localizedStandardContains("Program activation request/completion lifecycle is Runtime-owned"))
        XCTAssertTrue(normalizedDocs.localizedStandardContains("Program activation concrete switching side effects are still ViewModel-owned"))
    }

    func testProgramActivationSideEffectsRemainViewModelOwned() throws {
        let viewModel = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift"
        )
        let activation = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift"
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
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift"
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

        XCTAssertTrue(source.contains(".programActivation"))
        XCTAssertTrue(LiveRuntimeBridgeMode.programSelectionOwned.owns(.programSelection))
        XCTAssertFalse(LiveRuntimeBridgeMode.programSelectionOwned.owns(.programActivation))
        XCTAssertFalse(LiveRuntimeBridgeMode.programSelectionOwned.owns(.automation))
    }

    func testProductionViewModelRuntimeBridgeModeIsPanicOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .panicOwned)
    }

    func testProductionConnectedPortsRemainExplicitRuntimeSet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .panicDelay, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testSourceAvailabilityStillRunsBeforeRuntimeActivationRequest() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )
        let availabilityRange = try XCTUnwrap(source.range(of: "programSourceIsAvailable(activationItem)"))
        let requestRange = try XCTUnwrap(source.range(of: "operatorRequestedProgramActivation"))

        XCTAssertLessThan(availabilityRange.lowerBound, requestRange.lowerBound)
    }

    func testMissingSourceStillDoesNotDispatchActivationRequest() {
        let missingURL = URL(fileURLWithPath: "/tmp/liveswitcher-missing-program-activation-source.mp4")
        let item = ProgramItem(title: "Missing", subtitle: "VIDEO", sourceURL: missingURL)
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.switchToProgram(item)

        XCTAssertNil(viewModel.runtime.state.programActivation.activeRequestID)
        XCTAssertFalse(viewModel.runtime.recordedEffects.contains { effect in
            if case .executeProgramActivation = effect { return true }
            return false
        })
    }

    func testProgramActivationPlannerStillCalledFromViewModel() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains("ProgramActivationPlanner.plan("))
    }

    func testRuntimeReducerDoesNotReferenceProgramSourceAvailabilityPolicy() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift"
        )

        XCTAssertFalse(source.contains("ProgramSourceAvailabilityPolicy"))
    }

    func testRuntimeReducerDoesNotReferenceProgramActivationPlanner() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift"
        )

        XCTAssertFalse(source.contains("ProgramActivationPlanner"))
    }

    func testProgramActivationPortDoesNotReferenceProgramSourceAvailabilityPolicy() throws {
        let source = try programActivationPortSource()

        XCTAssertFalse(source.contains("ProgramSourceAvailabilityPolicy"))
    }

    func testProgramActivationPortDoesNotReferenceProgramActivationPlanner() throws {
        let source = try programActivationPortSource()

        XCTAssertFalse(source.contains("ProgramActivationPlanner"))
    }

    func testProgramActivationPortDoesNotValidateDeckDocument() throws {
        let source = try programActivationPortSource()

        XCTAssertFalse(source.contains("isLikelyValidDeckDocument"))
        XCTAssertFalse(source.contains("PresentationReadinessProbe"))
    }

    private func runtimeStateSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift")
    }

    private func programActivationPortSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift")
    }
}
