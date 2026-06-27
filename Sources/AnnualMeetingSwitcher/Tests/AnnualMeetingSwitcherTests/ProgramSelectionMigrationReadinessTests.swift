import XCTest
@testable import LiveSwitcher

final class ProgramSelectionMigrationReadinessTests: XCTestCase {
    func testProgramSelectionReducerLivesInDedicatedFile() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/ProgramSelectionRuntimeReducer.swift"
        )

        XCTAssertTrue(source.contains("enum ProgramSelectionRuntimeReducer"))
        XCTAssertTrue(source.contains("func selectProgram"))
        XCTAssertTrue(source.contains("func clearCurrentProgram"))
        XCTAssertTrue(source.contains("func selectedProgramItem"))
    }

    func testProgramSelectionHelpersNoLongerLiveInReducerFile() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift"
        )

        XCTAssertFalse(source.contains("static func reduceSelectedProgram"))
        XCTAssertFalse(source.contains("static func selectedProgramItem"))
    }

    func testProgramSelectionClearReasonIsExplicitAndLimited() {
        XCTAssertEqual(
            [
                ProgramSelectionClearReason.htmlPresentationEnded,
                .mediaPlaybackEnded,
                .operatorCleared
            ],
            [.htmlPresentationEnded, .mediaPlaybackEnded, .operatorCleared]
        )
    }

    func testProductionSelectionClearCallersUseClearHelper() throws {
        let mediaPlayback = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+MediaPlayback.swift"
        )
        let programQueue = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift"
        )

        XCTAssertTrue(mediaPlayback.contains("clearCurrentProgramSelection(reason: .htmlPresentationEnded)"))
        XCTAssertTrue(mediaPlayback.contains("clearCurrentProgramSelection(reason: .mediaPlaybackEnded)"))
        XCTAssertFalse(mediaPlayback.contains("applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)"))
        XCTAssertFalse(programQueue.contains("applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)"))
    }

    func testClearHelperOwnsOnlyNilProjectionFallback() throws {
        let programSelection = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramSelection.swift"
        )
        let runtimeFacadeSync = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacadeSync.swift"
        )

        XCTAssertTrue(programSelection.contains("func clearCurrentProgramSelection(reason: ProgramSelectionClearReason)"))
        XCTAssertTrue(programSelection.contains("dispatchRuntimeFacadeAction(.operatorClearedCurrentProgram(reason: reason))"))
        XCTAssertTrue(programSelection.contains("applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)"))

        XCTAssertFalse(runtimeFacadeSync.contains("func clearCurrentProgramSelection"))
        XCTAssertFalse(runtimeFacadeSync.contains("operatorClearedCurrentProgram"))
    }

    func testProgramActivationRuntimeLifecycleDomainAndEffectsExist() throws {
        let bridgeMode = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeBridgeMode.swift"
        )
        let domain = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeDomain.swift"
        )
        let effect = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffect.swift"
        )
        let action = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift"
        )

        XCTAssertTrue(bridgeMode.contains("programActivationOwned"))
        XCTAssertTrue(domain.contains("case programActivation"))
        XCTAssertTrue(effect.contains("executeProgramActivation"))
        XCTAssertTrue(action.contains("programActivationCompleted"))
        XCTAssertFalse(action.contains("programActivationFailed"))
    }

    func testActivationExecutorStillOwnsSideEffectDispatch() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift"
        )

        XCTAssertTrue(source.contains("programActivationSideEffects.presentKeynote"))
        XCTAssertTrue(source.contains("programActivationSideEffects.openPPTX"))
        XCTAssertTrue(source.contains("openHTMLInOutputWindow(url: url)"))
        XCTAssertTrue(source.contains("programActivationSideEffects.presentActiveDeck"))
        XCTAssertFalse(source.contains("activateProgram"))
    }
}
