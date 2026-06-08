import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramSelectionFacadeBoundaryTests: XCTestCase {
    func testClearCurrentProgramSelectionIsNotDeclaredInRuntimeFacadeSyncFile() throws {
        let source = try repositorySource(runtimeFacadeSyncPath)

        XCTAssertFalse(source.contains("func clearCurrentProgramSelection"))
    }

    func testClearCurrentProgramSelectionLivesInProgramSelectionExtension() throws {
        let source = try repositorySource(programSelectionPath)

        XCTAssertTrue(source.contains("func clearCurrentProgramSelection(reason: ProgramSelectionClearReason)"))
        XCTAssertTrue(source.contains("dispatchRuntimeFacadeAction(.operatorClearedCurrentProgram(reason: reason))"))
    }

    func testRuntimeFacadeSyncFileKeepsOnlySyncHelpers() throws {
        let source = try repositorySource(runtimeFacadeSyncPath)

        XCTAssertFalse(source.contains("operatorClearedCurrentProgram"))
        XCTAssertFalse(source.contains("applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)"))
    }

    func testClearCurrentProgramSelectionDispatchesRuntimeClearWhenOwned() {
        let item = programItem("Current")
        let viewModel = makeViewModel(initialItems: [item], bridgeMode: .programSelectionOwned)
        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedProgram(item.id))

        viewModel.clearCurrentProgramSelection(reason: .htmlPresentationEnded)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorClearedCurrentProgram" })
    }

    func testClearCurrentProgramSelectionFallsBackOnlyBeforeProgramSelectionOwnership() throws {
        let source = try repositorySource(programSelectionPath)

        XCTAssertTrue(source.contains("if runtime.bridgeMode.owns(.programSelection)"))
        XCTAssertTrue(source.contains("applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)"))
    }

    func testRuntimeReducerAudioHelpersRemainMarkedForDomainReducersOnly() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift"
        )

        XCTAssertTrue(source.contains("// Internal for domain reducers; do not call from ViewModel."))
        XCTAssertTrue(source.contains("internal static func recalculateAudio"))
        XCTAssertTrue(source.contains("internal static func syncAudioRoutingContextFromMirrorState"))
    }

    func testViewModelFilesDoNotCallLiveRuntimeReducerRecalculateAudio() throws {
        XCTAssertTrue(try viewModelSourceFilesContaining("LiveRuntimeReducer.recalculateAudio").isEmpty)
    }

    func testViewModelFilesDoNotCallLiveRuntimeReducerSyncAudioRoutingContext() throws {
        XCTAssertTrue(try viewModelSourceFilesContaining("LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState").isEmpty)
    }

    func testProgramSelectionRuntimeReducerMayCallRuntimeAudioHelpers() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/ProgramSelectionRuntimeReducer.swift"
        )

        XCTAssertTrue(source.contains("LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState"))
        XCTAssertTrue(source.contains("LiveRuntimeReducer.recalculateAudio"))
    }

    private var runtimeFacadeSyncPath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacadeSync.swift"
    }

    private var programSelectionPath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramSelection.swift"
    }

    private func viewModelSourceFilesContaining(_ needle: String) throws -> [String] {
        try viewModelSourceFiles().filter { try repositorySource($0).contains(needle) }
    }

    private func viewModelSourceFiles() throws -> [String] {
        let root = try repositoryRoot()
        let sourceRoot = root.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        guard let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return enumerator.compactMap { entry -> String? in
            guard let url = entry as? URL,
                  url.lastPathComponent.hasPrefix("ViewModel"),
                  url.pathExtension == "swift"
            else { return nil }
            return url.path.replacingOccurrences(of: root.path + "/", with: "")
        }
    }

    private func makeViewModel(
        initialItems: [ProgramItem],
        bridgeMode: LiveRuntimeBridgeMode
    ) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.program.items = initialItems
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let suiteName = "ProgramSelectionFacadeBoundaryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults, runtime: runtime)
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
