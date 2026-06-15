import XCTest
@testable import LiveSwitcher

@MainActor
final class PanicRuntimeFacadeHardeningTests: XCTestCase {
    func testIsPanicModeIsPrivateSetOrNarrowlyProjected() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertTrue(source.contains("private(set) var isPanicMode"))
    }

    func testPanicPlaybackSnapshotIsPrivateSetOrNarrowlyProjected() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertTrue(source.contains("private(set) var panicPlaybackSnapshot"))
    }

    func testPanicProjectionUsesNarrowApplyMethod() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "applyPanicProjectionFromRuntime"))

        XCTAssertTrue(body.contains("isPanicMode = isActive"))
        XCTAssertTrue(body.contains("panicPlaybackSnapshot = snapshot"))
    }

    func testPanicOwnedPathDoesNotAssignIsPanicModeDirectly() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "togglePanicMode"))
        let ownedBranch = try XCTUnwrap(body.balancedBlock(after: "if runtime.bridgeMode.owns(.panic)"))

        XCTAssertFalse(ownedBranch.contains("isPanicMode ="))
    }

    func testPanicOwnedPathDoesNotAssignPanicPlaybackSnapshotDirectly() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "togglePanicMode"))
        let ownedBranch = try XCTUnwrap(body.balancedBlock(after: "if runtime.bridgeMode.owns(.panic)"))

        XCTAssertFalse(ownedBranch.contains("panicPlaybackSnapshot ="))
    }

    func testPanicDelayPortDoesNotAssignIsPanicModeDirectly() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PanicDelayRuntimeWiring.swift")

        XCTAssertFalse(source.contains("isPanicMode ="))
    }

    func testPanicDelayPortDoesNotAssignPanicPlaybackSnapshotDirectly() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PanicDelayRuntimeWiring.swift")

        XCTAssertFalse(source.contains("panicPlaybackSnapshot ="))
    }

    func testViewModelFilesDoNotCallLiveRuntimeReducerRecalculateAudio() throws {
        for path in try viewModelSourcePaths() {
            let source = try repositorySource(path)

            XCTAssertFalse(source.contains("LiveRuntimeReducer.recalculateAudio"), path)
        }
    }

    func testViewModelFilesDoNotCallLiveRuntimeReducerSyncAudioRoutingContext() throws {
        for path in try viewModelSourcePaths() {
            let source = try repositorySource(path)

            XCTAssertFalse(source.contains("LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState"), path)
        }
    }

    func testPanicRuntimeReducerMayCallAudioRuntimeHelpers() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/PanicRuntimeReducer.swift")

        XCTAssertTrue(
            source.contains("AudioRuntimeReducer.recalculateAudio")
                || source.contains("AudioRuntimeReducer.syncRoutingContextFromMirrorState")
        )
    }

    func testPanicOwnedMediaPlaybackDoesNotMutateFacadePanicSnapshot() {
        let programID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let viewModel = makeViewModel(bridgeMode: .panicOwned)
        viewModel.applyPanicProjectionFromRuntime(
            isActive: true,
            snapshot: PanicPlaybackSnapshot(
                currentProgramID: programID,
                wasMediaPlaying: true,
                currentBGMID: nil,
                wasBGMPlaying: false
            )
        )

        viewModel.markPanicSnapshotMediaStoppedIfCurrentProgram(programID)

        XCTAssertTrue(viewModel.panicPlaybackSnapshot?.wasMediaPlaying == true)
    }

    func testPanicOwnedBGMFinishDoesNotMutateFacadePanicSnapshot() {
        let bgmID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let viewModel = makeViewModel(bridgeMode: .panicOwned)
        viewModel.applyPanicProjectionFromRuntime(
            isActive: true,
            snapshot: PanicPlaybackSnapshot(
                currentProgramID: nil,
                wasMediaPlaying: false,
                currentBGMID: bgmID,
                wasBGMPlaying: true
            )
        )

        viewModel.markPanicSnapshotBGMStoppedIfCurrentBGM(bgmID)

        XCTAssertTrue(viewModel.panicPlaybackSnapshot?.wasBGMPlaying == true)
    }

    func testPanicOwnedBGMFailDoesNotMutateFacadePanicSnapshot() {
        let bgmID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let viewModel = makeViewModel(bridgeMode: .panicOwned)
        viewModel.applyPanicProjectionFromRuntime(
            isActive: true,
            snapshot: PanicPlaybackSnapshot(
                currentProgramID: nil,
                wasMediaPlaying: false,
                currentBGMID: bgmID,
                wasBGMPlaying: true
            )
        )

        viewModel.markPanicSnapshotBGMStoppedIfCurrentBGM(bgmID)

        XCTAssertTrue(viewModel.panicPlaybackSnapshot?.wasBGMPlaying == true)
    }

    func testPanicOwnedCueBGMDuringPanicDoesNotMutateFacadePanicSnapshot() {
        let bgmID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
        let viewModel = makeViewModel(bridgeMode: .panicOwned)
        viewModel.applyPanicProjectionFromRuntime(
            isActive: true,
            snapshot: PanicPlaybackSnapshot(
                currentProgramID: nil,
                wasMediaPlaying: false,
                currentBGMID: bgmID,
                wasBGMPlaying: true
            )
        )

        viewModel.markPanicSnapshotBGMStoppedIfCurrentBGM(bgmID)

        XCTAssertTrue(viewModel.panicPlaybackSnapshot?.wasBGMPlaying == true)
    }

    func testLegacyMediaPlaybackCanStillMutateFacadePanicSnapshotBeforeOwnership() {
        let programID = UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
        let viewModel = makeViewModel(bridgeMode: .recordingOnly)
        viewModel.applyPanicProjectionFromRuntime(
            isActive: true,
            snapshot: PanicPlaybackSnapshot(
                currentProgramID: programID,
                wasMediaPlaying: true,
                currentBGMID: nil,
                wasBGMPlaying: false
            )
        )

        viewModel.markPanicSnapshotMediaStoppedIfCurrentProgram(programID)

        XCTAssertFalse(viewModel.panicPlaybackSnapshot?.wasMediaPlaying == true)
    }

    func testLegacyBGMFinishCanStillMutateFacadePanicSnapshotBeforeOwnership() {
        let bgmID = UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
        let viewModel = makeViewModel(bridgeMode: .recordingOnly)
        viewModel.applyPanicProjectionFromRuntime(
            isActive: true,
            snapshot: PanicPlaybackSnapshot(
                currentProgramID: nil,
                wasMediaPlaying: false,
                currentBGMID: bgmID,
                wasBGMPlaying: true
            )
        )

        viewModel.markPanicSnapshotBGMStoppedIfCurrentBGM(bgmID)

        XCTAssertFalse(viewModel.panicPlaybackSnapshot?.wasBGMPlaying == true)
    }

    func testPanicSnapshotMutationHelpersAreLegacyNamedOrOwnershipGuarded() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertTrue(
            source.contains("markLegacyPanicSnapshotMediaStoppedIfCurrentProgram")
                || source.contains("guard !runtime.bridgeMode.owns(.panic) else { return }")
        )
        XCTAssertTrue(
            source.contains("markLegacyPanicSnapshotBGMStoppedIfCurrentBGM")
                || source.contains("guard !runtime.bridgeMode.owns(.panic) else { return }")
        )
    }

    private func viewModelSourcePaths() throws -> [String] {
        let root = try repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        let files = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        )
        return files
            .filter { $0.lastPathComponent.hasPrefix("ViewModel") && $0.pathExtension == "swift" }
            .map { "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/\($0.lastPathComponent)" }
    }

    private func makeViewModel(bridgeMode: LiveRuntimeBridgeMode) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
    }
}
