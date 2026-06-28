import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelEncapsulationTests: XCTestCase {
    func testSupportEventsIsNotDirectlyAssignedOutsideRuntimeFacadeSync() throws {
        let sources = try viewModelSourceFiles()
        let offenders = try sources.flatMap { path -> [String] in
            try repositorySource(path)
                .split(separator: "\n")
                .map(String.init)
                .filter { line in
                    line.contains("supportEvents =")
                        && !line.contains("private(set) var supportEvents")
                        && !line.contains("supportEvents = events")
                }
                .map { "\(path): \($0.trimmingCharacters(in: .whitespaces))" }
        }

        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: "\n"))
    }

    func testRecordSupportEventStillSyncsSupportFacadeFromRuntime() {
        let viewModel = makeViewModel()

        viewModel.recordSupportEvent(kind: .projectionStarted, detail: "source=encapsulation-test")

        XCTAssertEqual(viewModel.supportEvents, viewModel.runtime.state.support.events)
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionStarted })
    }

    func testRuntimeFacadeUsesValidatedMediaCallbackGeneration() throws {
        let source = try runtimeFacadeSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "dispatchRuntimeMediaCallback"))

        XCTAssertTrue(body.contains("validatedRuntimeMediaCallbackGeneration()"))
        XCTAssertFalse(body.contains("activeRuntimeMediaGenerationForCallbacks"))
        XCTAssertFalse(body.contains("activeRuntimeMediaURLForCallbacks"))
    }

    func testRuntimeFacadeUsesValidatedBGMCallbackGeneration() throws {
        let source = try runtimeFacadeSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "dispatchRuntimeBGMCallback"))

        XCTAssertTrue(body.contains("validatedRuntimeBGMCallbackGeneration()"))
        XCTAssertFalse(body.contains("activeRuntimeBGMGenerationForCallbacks"))
        XCTAssertFalse(body.contains("activeRuntimeBGMItemIDForCallbacks"))
        XCTAssertFalse(body.contains("activeRuntimeBGMURLForCallbacks"))
    }

    func testBGMCallbackMismatchStillReturnsFalse() {
        let viewModel = makeViewModel()
        let first = BGMItem(title: "First", url: URL(fileURLWithPath: "/tmp/first.mp3"))
        let second = BGMItem(title: "Second", url: URL(fileURLWithPath: "/tmp/second.mp3"))
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        let activeGeneration = viewModel.activeRuntimeBGMCallbackGenerationForTesting ?? 0
        viewModel.currentBGMItem = second
        var state = viewModel.runtime.state
        state.bgm.items = [first, second]
        state.bgm.currentID = second.id
        state.bgm.generation = activeGeneration
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testMediaCallbackMismatchStillNoops() {
        let viewModel = makeViewModel()
        let item = ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/video-\(UUID().uuidString).mp4")
        )
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)
        viewModel.avCoordinator.load(url: URL(fileURLWithPath: "/tmp/other-\(UUID().uuidString).mp4"))
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.dispatchRuntimeMediaCallback {
            .mediaPlaybackChanged(isPlaying: true, generation: $0)
        }

        XCTAssertTrue(viewModel.runtime.actionLog.isEmpty)
    }

    func testRawPageInterceptEventTapIsNotReferencedOutsideViewModelCore() throws {
        let offenders = try viewModelSourceFiles()
            .filter { !$0.hasSuffix("ViewModel.swift") }
            .filter { !$0.hasSuffix("ViewModel+PPTEventTap.swift") }
            .filter { try repositorySource($0).contains("pageInterceptEventTap") }

        XCTAssertTrue(offenders.isEmpty, offenders.joined(separator: "\n"))
    }

    func testPPTSnapshotStillMirrorsRequestedStateWhenPPTOwnershipIsNotRuntime() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .projectionOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.isPageInterceptEnabled = true

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
    }

    func testPersistencePortStillWritesConsoleMode() throws {
        let (viewModel, defaults) = try makeViewModelWithDefaults()

        viewModel.consoleMode = .live

        XCTAssertEqual(defaults.string(forKey: "consoleMode"), ConsoleMode.live.rawValue)
    }

    func testPersistencePortStillWritesAudioStrategy() throws {
        let (viewModel, defaults) = try makeViewModelWithDefaults()

        viewModel.audioStrategy = .bgmOnly

        XCTAssertEqual(defaults.string(forKey: "audioStrategy"), AudioStrategy.bgmOnly.rawValue)
    }

    func testPersistencePortStillWritesBGMPlayMode() throws {
        let (viewModel, defaults) = try makeViewModelWithDefaults()

        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedBGMPlayMode(.sequential))

        XCTAssertEqual(defaults.string(forKey: "bgmPlayMode"), BGMPlayMode.sequential.rawValue)
    }

    func testPersistencePortStillWritesCornerLogoPosition() throws {
        let (viewModel, defaults) = try makeViewModelWithDefaults()

        viewModel.cornerLogoPosition = .bottomLeft

        XCTAssertEqual(defaults.string(forKey: "cornerLogo_position"), CornerLogoPosition.bottomLeft.rawValue)
    }

    func testRuntimeEnvironmentSyncUsesReadOnlySpeakerRatioAccessor() throws {
        let source = try runtimeFacadeSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "syncRuntimeEnvironmentFromFacade"))

        XCTAssertTrue(body.contains("runtimeSpeakerModeDuckedRatio"))
        XCTAssertFalse(body.contains("speakerModeDuckedRatio,"))
    }

    func testRuntimeEnvironmentSyncStillPreservesLiveAudioFadeDuration() throws {
        let source = try runtimeFacadeSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "syncRuntimeEnvironmentFromFacade"))

        XCTAssertTrue(body.contains("liveAudioFadeDuration: liveAudioFadeDuration"))
    }

    func testRuntimeEnvironmentSyncStillPreservesBridgeMode() throws {
        let source = try runtimeFacadeSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "syncRuntimeEnvironmentFromFacade"))

        XCTAssertTrue(body.contains("bridgeMode: runtime.bridgeMode"))
        XCTAssertEqual(makeViewModel().runtimeBridgeMode, .panicOwned)
    }

    func testNoNewUngroupedTestHooksWereAdded() throws {
        let source = try viewModelSource()
        let hookLines = source
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.contains("ForTesting") || $0.contains("StartOverride") || $0.contains("DidRun") }
            .filter { line in
                line.contains("@ObservationIgnored var")
                    && !line.contains("testHooks")
                    && !line.contains("runtimeFacadeDispatchSuppressionDepth")
            }

        XCTAssertTrue(hookLines.isEmpty, hookLines.joined(separator: "\n"))
    }

    func testProductionViewModelRuntimeBridgeModeIsProgramActivationOwned() {
        XCTAssertEqual(makeViewModel().runtimeBridgeMode, .panicOwned)
    }

    func testProductionConnectedPortsIncludeProgramActivationSet() {
        let expected: Set<LiveRuntimeEffectPortKind> = [
            .media,
            .bgm,
            .bgmTimer,
            .panicDelay,
            .projection,
            .ppt,
            .automationNotice,
            .support,
            .automation,
            .presentationQuery,
            .programActivation,
            .audioRouting,
            .imageAssets,
            .persistence
        ]

        XCTAssertEqual(makeViewModel().runtimeConnectedPortKinds, expected)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ViewModelEncapsulationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }

    private func makeViewModelWithDefaults() throws -> (SwitcherViewModel, UserDefaults) {
        let suiteName = "ViewModelEncapsulationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        return (viewModel, defaults)
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func runtimeFacadeSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacade.swift")
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
