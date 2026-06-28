import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelMainHygieneTests: XCTestCase {
    func testPPTModeFacadeMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func togglePPTMode("))
        XCTAssertFalse(source.contains("func setPPTMode("))
        XCTAssertFalse(source.contains("func dispatchPPTIntent("))
    }

    func testPPTModeFacadeMethodsLiveInPPTModeExtension() throws {
        let source = try XCTUnwrap(
            optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PPTMode.swift")
        )

        XCTAssertTrue(source.contains("func togglePPTMode("))
        XCTAssertTrue(source.contains("func setPPTMode("))
        XCTAssertTrue(source.contains("func dispatchPPTIntent("))
    }

    func testTogglePPTModeStillDispatchesRuntimeAction() {
        let viewModel = makeViewModel()

        viewModel.togglePPTMode(source: .liveMode)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledPPTMode" })
    }

    func testSetPPTModeStillDispatchesRuntimeAction() {
        let viewModel = makeViewModel()

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSetPPTMode" })
    }

    func testPendingPPTToggleSourceStillClearedWhenRuntimeNoops() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: .productionAudioOwned()
        )
        let viewModel = makeViewModel(runtime: runtime)

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertNil(viewModel.currentPendingPPTToggleSource())
    }

    func testRuntimeIdentityAccessorsLiveInFocusedExtension() throws {
        let source = try viewModelSource()
        let runtimeIdentitySource = try sourceText(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeIdentity.swift"
        )

        XCTAssertNil(source.range(of: "func setActiveRuntimeMediaCallbackIdentity("))
        XCTAssertNil(source.range(of: "func validatedRuntimeBGMCallbackGeneration()"))
        XCTAssertNotNil(runtimeIdentitySource.range(of: "func setActiveRuntimeMediaCallbackIdentity("))
        XCTAssertNotNil(runtimeIdentitySource.range(of: "func validatedRuntimeBGMCallbackGeneration()"))
        XCTAssertNotNil(source.range(of: "var runtimeSpeakerModeDuckedRatio"))
    }

    func testPrivateStorageRemainsEncapsulatedBehindMainViewModelStore() throws {
        let source = try viewModelSource()
        let store = try sourceText(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel/Internal/ViewModelRuntimeIdentityStore.swift"
        )

        XCTAssertNotNil(source.range(of: "@ObservationIgnored var runtimeIdentityStore"))
        XCTAssertNil(source.range(of: "@ObservationIgnored private var activeRuntimeMediaGenerationForCallbacks"))
        XCTAssertNil(source.range(of: "@ObservationIgnored private var activeRuntimeBGMGenerationForCallbacks"))
        XCTAssertNotNil(store.range(of: "private(set) var activeMediaGeneration"))
        XCTAssertNotNil(store.range(of: "private(set) var activeBGMGeneration"))
        XCTAssertTrue(source.contains("private let speakerModeDuckedRatio"))
        XCTAssertTrue(source.contains("private(set) var isExternalDisplayAvailable"))
    }

    func testMainViewModelDoesNotContainDomainMethodBodies() throws {
        let source = try viewModelSource()

        [
            "func switchToProgram(",
            "func saveData(",
            "func setupPlayerCoordinator(",
            "func configureRuntimePortHandlers(",
            "func showOutputWindowFromRuntimeProjection(",
            "func startPPTEventTapFromRuntime("
        ].forEach { snippet in
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testMainViewModelDoesNotContainLooseActionHandlers() throws {
        let source = try viewModelSource()

        [
            "var keynotePresentationHandler",
            "var pptxOpenHandler",
            "var deckStopHandler",
            "var programSeekToStartHandler",
            "var programRestartFromBeginningHandler",
            "var programSeekToEndHandler",
            "var activeDeckPresentationHandler",
            "var invalidDeckHandler"
        ].forEach { snippet in
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testMainViewModelDoesNotContainLooseTestHooks() throws {
        let source = try viewModelSource()

        [
            "var pageInterceptStartOverride",
            "var scanOpenKeynoteFilesForTesting",
            "var scanKeynoteWindowNamesForTesting",
            "var automationCommandRunnerForTesting",
            "var automationCommandDidFinishForTesting",
            "var saveDataDidRun"
        ].forEach { snippet in
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testRootViewModelShellIsUnderBudgetAndRemovedFromAllowlist() throws {
        let source = try viewModelSource()
        let allowlist = try sourceText("docs/architecture/complexity-allowlist.tsv")

        XCTAssertLessThan(source.split(separator: "\n", omittingEmptySubsequences: false).count, 400)
        XCTAssertNil(allowlist.range(of: "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift"))
    }

    func testFocusedViewModelExtensionFilesStayUnderBudget() throws {
        for path in focusedExtensionPaths {
            let source = try sourceText(path)
            XCTAssertLessThan(
                source.split(separator: "\n", omittingEmptySubsequences: false).count,
                400,
                path
            )
            XCTAssertNotNil(source.range(of: "extension SwitcherViewModel"), path)
        }
    }

    private func makeViewModel(runtime: LiveRuntimeStore? = nil) -> SwitcherViewModel {
        let suiteName = "ViewModelMainHygieneTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private var focusedExtensionPaths: [String] {
        [
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeIdentity.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProjectionAccessors.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PageInterceptAccessors.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+TestingAccessors.swift"
        ]
    }
}
