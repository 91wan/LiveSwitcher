import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramActivationRuntimeHardeningTests: XCTestCase {
    func testProductionViewModelRuntimeBridgeModeRemainsProgramActivationOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .programActivationOwned)
    }

    func testProductionConnectedPortsIncludeProgramActivation() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.programActivation))
    }

    func testProductionConnectedPortsRemainExactActivationRuntimeSet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testActivationEffectChecksActiveRequestBeforeSideEffects() throws {
        let source = try bridgeSource()
        let guardRange = try XCTUnwrap(source.range(of: "context.currentState().programActivation.activeRequestID == id"))
        let preSelectionRange = try XCTUnwrap(source.range(of: "for effect in plan.preSelectionEffects"))

        XCTAssertLessThan(guardRange.lowerBound, preSelectionRange.lowerBound)
    }

    func testActivationEffectConfirmsRuntimeSelectionBeforePostSelectionEffects() throws {
        let source = try bridgeSource()
        let confirmRange = try XCTUnwrap(source.range(of: "dispatchProgramActivationRuntimeSelectionAndConfirm"))
        let postSelectionRange = try XCTUnwrap(source.range(of: "for effect in plan.postSelectionEffects"))

        XCTAssertLessThan(confirmRange.lowerBound, postSelectionRange.lowerBound)
        XCTAssertTrue(source.contains("context.currentState().program.effectiveCurrentItem?.id == expectedItemID"))
    }

    func testRuntimeOwnershipDocsDescribeActivationHardeningBoundary() throws {
        let docs = try repositorySource("docs/architecture/runtime-ownership.md")
        let normalizedDocs = docs.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        XCTAssertTrue(normalizedDocs.localizedStandardContains("executes only while Runtime's active request ID matches its request ID"))
        XCTAssertTrue(normalizedDocs.localizedStandardContains("verifies that Runtime accepted the requested selection before post-selection side effects run"))
        XCTAssertTrue(normalizedDocs.localizedStandardContains("stale activation effects must not run side effects"))
        XCTAssertTrue(normalizedDocs.localizedStandardContains("rejected selection must not run post-selection side effects"))
    }

    private func bridgeSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift")
    }
}
