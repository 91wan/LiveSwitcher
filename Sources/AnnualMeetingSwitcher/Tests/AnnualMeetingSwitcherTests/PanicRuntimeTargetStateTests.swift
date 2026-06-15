import XCTest
@testable import LiveSwitcher

@MainActor
final class PanicRuntimeTargetStateTests: XCTestCase {
    func testTogglePanicOwnedUsesRuntimeStateAsTargetSource() {
        let viewModel = makePanicOwnedViewModel(runtimeIsActive: false, facadeIsActive: true)

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.runtime.state.panic.isActive)
        XCTAssertTrue(viewModel.isPanicMode)
    }

    func testTogglePanicOwnedDoesNotUseFacadeAsTargetSource() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "togglePanicMode"))
        let ownedBranch = try XCTUnwrap(body.balancedBlock(after: "if runtime.bridgeMode.owns(.panic)"))

        XCTAssertTrue(ownedBranch.contains("runtime.state.panic.isActive"))
        XCTAssertFalse(ownedBranch.contains("!isPanicMode"))
    }

    func testTogglePanicOwnedTurnsOnFromRuntimeFalseEvenIfFacadeStaleTrue() {
        let viewModel = makePanicOwnedViewModel(runtimeIsActive: false, facadeIsActive: true)

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.runtime.state.panic.isActive)
        XCTAssertTrue(viewModel.isPanicMode)
    }

    func testTogglePanicOwnedTurnsOffFromRuntimeTrueEvenIfFacadeStaleFalse() {
        let viewModel = makePanicOwnedViewModel(runtimeIsActive: true, facadeIsActive: false)

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.runtime.state.panic.isActive)
        XCTAssertFalse(viewModel.isPanicMode)
    }

    func testTogglePanicOwnedRecordsSupportUsingRuntimeResult() {
        let viewModel = makePanicOwnedViewModel(runtimeIsActive: false, facadeIsActive: true)

        viewModel.togglePanicMode()

        XCTAssertEqual(viewModel.supportEvents.last?.kind, .panicModeChanged)
        XCTAssertEqual(viewModel.supportEvents.last?.detail, "isOn=true")
    }

    func testTogglePanicOwnedDoesNotRecordSupportWhenRuntimeNoops() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "togglePanicMode"))
        let ownedBranch = try XCTUnwrap(body.balancedBlock(after: "if runtime.bridgeMode.owns(.panic)"))

        let guardRange = try XCTUnwrap(ownedBranch.range(of: "guard newValue != oldValue else { return }"))
        let supportRange = try XCTUnwrap(ownedBranch.range(of: "recordSupportEvent"))
        XCTAssertTrue(supportRange.lowerBound > guardRange.upperBound)
    }

    private func makePanicOwnedViewModel(
        runtimeIsActive: Bool,
        facadeIsActive: Bool
    ) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.panic.isActive = runtimeIsActive
        state.panic.snapshot = runtimeIsActive ? panicSnapshot() : nil
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionPanicOwning()
        )
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, runtime: runtime)
        viewModel.applyPanicProjectionFromRuntime(
            isActive: facadeIsActive,
            snapshot: facadeIsActive ? panicSnapshot() : nil
        )
        return viewModel
    }

    private func panicSnapshot() -> PanicPlaybackSnapshot {
        PanicPlaybackSnapshot(
            currentProgramID: nil,
            wasMediaPlaying: false,
            currentBGMID: nil,
            wasBGMPlaying: false
        )
    }
}
