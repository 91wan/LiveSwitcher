import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelEncapsulationTests: XCTestCase {
    func testSupportEventsIsPrivateSet() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("private(set) var supportEvents"))
        XCTAssertFalse(source.contains("\n    var supportEvents: [LiveSupportEvent] = []"))
    }

    func testSupportFacadeProjectionUsesNarrowRuntimeApplyMethod() throws {
        let viewModel = try viewModelSource()
        let sync = try runtimeFacadeSyncSource()

        XCTAssertTrue(viewModel.contains("func applySupportEventsProjectionFromRuntime(_ events: [LiveSupportEvent])"))
        XCTAssertTrue(sync.contains("applySupportEventsProjectionFromRuntime(runtime.state.support.events)"))
    }

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

    func testRuntimeMediaCallbackIdentityFieldsArePrivate() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("@ObservationIgnored private var activeRuntimeMediaGenerationForCallbacks"))
        XCTAssertTrue(source.contains("@ObservationIgnored private var activeRuntimeMediaURLForCallbacks"))
    }

    func testRuntimeBGMCallbackIdentityFieldsArePrivate() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("@ObservationIgnored private var activeRuntimeBGMGenerationForCallbacks"))
        XCTAssertTrue(source.contains("@ObservationIgnored private var activeRuntimeBGMItemIDForCallbacks"))
        XCTAssertTrue(source.contains("@ObservationIgnored private var activeRuntimeBGMURLForCallbacks"))
    }

    func testTransientRuntimeBGMItemIsPrivate() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("@ObservationIgnored private var transientRuntimeBGMItem"))
    }

    func testRuntimeWiringUsesMediaCallbackIdentityMethods() throws {
        let source = try runtimeWiringSource()

        XCTAssertTrue(source.contains("setActiveRuntimeMediaCallbackIdentity(generation: generation, url: url)"))
        XCTAssertTrue(source.contains("clearActiveRuntimeMediaCallbackIdentity(ifGeneration: generation)"))
        XCTAssertFalse(source.contains("activeRuntimeMediaGenerationForCallbacks = generation"))
        XCTAssertFalse(source.contains("activeRuntimeMediaURLForCallbacks = url"))
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
        viewModel.currentBGMItem = second

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

    func testPageInterceptEventTapIsFacadeScoped() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("private var pageInterceptEventTap: CFMachPort?"))
        XCTAssertFalse(source.contains("\n    var pageInterceptEventTap: CFMachPort?"))
        XCTAssertFalse(source.contains("public var pageInterceptEventTap"))
        XCTAssertFalse(source.contains("open var pageInterceptEventTap"))
    }

    func testRuntimeSnapshotUsesPageInterceptTapActiveAccessor() throws {
        let source = try runtimeSnapshotSource()

        XCTAssertTrue(source.contains("state.ppt.isEventTapActive = isPageInterceptEventTapActiveForRuntimeSnapshot"))
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

    func testUserDefaultsStorageIsPrivate() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("private let userDefaults: UserDefaults"))
        XCTAssertFalse(source.contains("\n    let userDefaults: UserDefaults"))
    }

    func testUDKeysIsPrivateOrMovedOutOfViewModel() throws {
        let source = try viewModelSource()

        if source.contains("enum UDKeys") {
            XCTAssertTrue(source.contains("private enum UDKeys"))
        }
    }

    func testRuntimeWiringDoesNotDirectlySetUserDefaultsKeys() throws {
        let source = try runtimeWiringSource()

        XCTAssertFalse(source.contains("userDefaults.set"))
        XCTAssertFalse(source.contains("UDKeys."))
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

    func testSpeakerModeDuckedRatioIsPrivate() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("private let speakerModeDuckedRatio"))
        XCTAssertFalse(source.contains("\n    let speakerModeDuckedRatio"))
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
        XCTAssertEqual(makeViewModel().runtimeBridgeMode, .programQueueOwned)
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
            }

        XCTAssertTrue(hookLines.isEmpty, hookLines.joined(separator: "\n"))
    }

    func testMainViewModelDoesNotOwnProgramQueueMethodBodies() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func switchToProgram("))
        XCTAssertFalse(source.contains("func addProgramItem("))
        XCTAssertFalse(source.contains("func removeProgramItem("))
        XCTAssertFalse(source.contains("func agendaAutoAdvancePrompt("))
    }

    func testMainViewModelDoesNotOwnPresentationAutomationMethodBodies() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func openAndPresentKeynote("))
        XCTAssertFalse(source.contains("func openPPTXWithKeynote("))
        XCTAssertFalse(source.contains("func scanKeynoteWindowNames("))
        XCTAssertFalse(source.contains("func runAutomationScript("))
    }

    func testMainViewModelDoesNotOwnAutomationFailureMethodBodies() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func handleAppleScriptFailure("))
        XCTAssertFalse(source.contains("func dismissAutomationRuntimeNotice("))
        XCTAssertFalse(source.contains("func showAutomationRuntimeNotice("))
        XCTAssertFalse(source.contains("func presentAutomationAlert("))
    }

    func testMainViewModelDoesNotOwnPersistenceMethodBodies() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func saveData("))
        XCTAssertFalse(source.contains("func loadData("))
        XCTAssertFalse(source.contains("func applyPersistentState("))
    }

    func testMainViewModelDoesNotOwnRuntimeBridgeMethodBodies() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func dispatchRuntimeFacadeAction("))
        XCTAssertFalse(source.contains("func syncRuntimeStateFromFacade("))
        XCTAssertFalse(source.contains("func makeRuntimeFacadeSnapshot("))
        XCTAssertFalse(source.contains("func configureRuntimePortHandlers("))
    }

    func testMainViewModelStillOwnsFacadeStateAndInitOnly() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("final class SwitcherViewModel"))
        XCTAssertTrue(source.contains("init("))
        XCTAssertTrue(source.contains("var currentProgramItem: ProgramItem?"))
        XCTAssertTrue(source.contains("let runtime: LiveRuntimeStore"))
        XCTAssertTrue(source.contains("deinit"))
    }

    func testProductionViewModelRuntimeBridgeModeIsProgramQueueOwned() {
        XCTAssertEqual(makeViewModel().runtimeBridgeMode, .programQueueOwned)
    }

    func testProductionConnectedPortsIncludePresentationQuerySet() {
        let expected: Set<LiveRuntimeEffectPortKind> = [
            .media,
            .bgm,
            .bgmTimer,
            .projection,
            .ppt,
            .automationNotice,
            .support,
            .automation,
            .presentationQuery,
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

    private func runtimeFacadeSyncSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacadeSync.swift")
    }

    private func runtimeSnapshotSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift")
    }

    private func runtimeWiringSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeWiring.swift")
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
