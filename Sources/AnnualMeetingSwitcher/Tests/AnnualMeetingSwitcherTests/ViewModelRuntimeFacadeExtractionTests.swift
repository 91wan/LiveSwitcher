import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelRuntimeFacadeExtractionTests: XCTestCase {
    func testRuntimeFacadeDispatchIsNotDeclaredInViewModel() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertFalse(source.contains("func dispatchRuntimeFacadeAction("))
        XCTAssertFalse(source.contains("func dispatchRuntimeMediaCallback("))
        XCTAssertFalse(source.contains("func dispatchRuntimeBGMCallback("))
        XCTAssertFalse(source.contains("func syncRuntimeAudioInputsFromFacade("))
    }

    func testRuntimeFacadeDispatchLivesInRuntimeFacadeExtension() throws {
        let source = try XCTUnwrap(runtimeFacadeSource())

        XCTAssertTrue(source.contains("extension SwitcherViewModel"))
        XCTAssertTrue(source.contains("func dispatchRuntimeFacadeAction(_ action: LiveRuntimeAction)"))
    }

    func testRuntimeMediaCallbackBridgeLivesInRuntimeFacadeExtension() throws {
        let source = try XCTUnwrap(runtimeFacadeSource())

        XCTAssertTrue(source.contains("func dispatchRuntimeMediaCallback(_ makeAction: (Int) -> LiveRuntimeAction)"))
    }

    func testRuntimeBGMCallbackBridgeLivesInRuntimeFacadeExtension() throws {
        let source = try XCTUnwrap(runtimeFacadeSource())

        XCTAssertTrue(source.contains("func dispatchRuntimeBGMCallback(_ makeAction: (Int) -> LiveRuntimeAction) -> Bool"))
        XCTAssertTrue(source.contains("func dispatchRuntimeBGMProgressCallback(time: Double, duration: Double?)"))
    }

    func testRuntimeAudioInputSyncLivesInRuntimeFacadeExtension() throws {
        let source = try XCTUnwrap(runtimeFacadeSource())

        XCTAssertTrue(source.contains("func syncRuntimeAudioInputsFromFacade(reason: AudioRoutingRuntimeChangeReason?)"))
    }

    func testDispatchRuntimeFacadeActionStillUsesFacadeSyncPolicy() throws {
        let source = try XCTUnwrap(runtimeFacadeSource())
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "dispatchRuntimeFacadeAction"))

        XCTAssertTrue(body.contains("LiveRuntimeFacadeSyncPolicy.options(for: action)"))
    }

    func testDispatchRuntimeFacadeActionStillSyncsRuntimeEnvironmentBeforeDispatch() throws {
        let source = try XCTUnwrap(runtimeFacadeSource())
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "dispatchRuntimeFacadeAction"))

        XCTAssertTrue(body.contains("syncRuntimeEnvironmentFromFacade()"))
        XCTAssertLessThan(
            try XCTUnwrap(body.range(of: "syncRuntimeEnvironmentFromFacade()")?.lowerBound),
            try XCTUnwrap(body.range(of: "runtime.dispatch(action)")?.lowerBound)
        )
    }

    func testDispatchRuntimeFacadeActionStillDispatchesRuntimeAction() throws {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.dispatchRuntimeFacadeAction(.operatorSetConsoleMode(.live))

        XCTAssertEqual(viewModel.runtime.state.mode, .live)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSetConsoleMode" })
    }

    func testRuntimeBridgeExtractionDoesNotIntroducePublicViewModelInternals() throws {
        let sources = try viewModelSourceFiles().map { try repositorySource($0) }.joined(separator: "\n")

        XCTAssertFalse(sources.contains("\n    public "))
        XCTAssertFalse(sources.contains("\n    open "))
    }

    func testUDKeysIsNotPublic() throws {
        let viewModel = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let keys = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/SwitcherPersistenceKeys.swift")

        XCTAssertFalse(viewModel.contains("enum UDKeys"))
        XCTAssertTrue(keys.contains("enum SwitcherPersistenceKeys"))
        XCTAssertFalse(keys.contains("public enum SwitcherPersistenceKeys"))
    }

    func testUserDefaultsStorageIsNotPublic() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertTrue(source.contains("let userDefaults: UserDefaults"))
        XCTAssertFalse(source.contains("public let userDefaults"))
        XCTAssertFalse(source.contains("public var userDefaults"))
    }

    func testRuntimeCallbackGenerationStateIsNotPublic() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertTrue(source.contains("activeRuntimeMediaGenerationForCallbacks"))
        XCTAssertFalse(source.contains("public var activeRuntimeMediaGenerationForCallbacks"))
        XCTAssertFalse(source.contains("public var activeRuntimeBGMGenerationForCallbacks"))
    }

    func testNoNewPublicTestHooksWereAdded() throws {
        let sources = try viewModelSourceFiles().map { try repositorySource($0) }.joined(separator: "\n")

        XCTAssertFalse(sources.contains("public func"))
        XCTAssertFalse(sources.contains("public var"))
        XCTAssertFalse(sources.contains("public let"))
    }

    private func runtimeFacadeSource() throws -> String? {
        try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacade.swift")
    }

    private func viewModelSourceFiles() throws -> [String] {
        let sourceRoot = try repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        let urls = try FileManager.default.contentsOfDirectory(at: sourceRoot, includingPropertiesForKeys: nil)
        return urls
            .filter { $0.lastPathComponent.hasPrefix("ViewModel") && $0.pathExtension == "swift" }
            .map { "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/\($0.lastPathComponent)" }
    }
}
