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

    func testPanicRuntimeReducerMayCallRuntimeAudioHelpers() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/PanicRuntimeReducer.swift")

        XCTAssertTrue(
            source.contains("LiveRuntimeReducer.recalculateAudio")
                || source.contains("LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState")
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
}
