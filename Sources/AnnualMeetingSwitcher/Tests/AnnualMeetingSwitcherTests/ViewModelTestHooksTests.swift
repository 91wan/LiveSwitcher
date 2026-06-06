import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelTestHooksTests: XCTestCase {
    func testViewModelTestHooksStructExists() {
        var hooks = SwitcherViewModelTestHooks()

        hooks.pageInterceptStartOverride = { true }
        hooks.scanOpenKeynoteFiles = { [] }
        hooks.scanKeynoteWindowNames = { [] }
        hooks.automationCommandRunner = { _, _ in }
        hooks.automationCommandDidFinish = {}
        hooks.saveDataDidRun = {}

        XCTAssertNotNil(hooks.pageInterceptStartOverride)
        XCTAssertNotNil(hooks.scanOpenKeynoteFiles)
        XCTAssertNotNil(hooks.scanKeynoteWindowNames)
        XCTAssertNotNil(hooks.automationCommandRunner)
        XCTAssertNotNil(hooks.automationCommandDidFinish)
        XCTAssertNotNil(hooks.saveDataDidRun)
    }

    func testViewModelTestHooksAreGrouped() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("@ObservationIgnored var testHooks = SwitcherViewModelTestHooks()"))
    }

    func testOldLooseTestHookNamesAreRemovedFromViewModel() throws {
        let source = try viewModelSource()

        [
            "pageInterceptStartOverride:",
            "scanOpenKeynoteFilesForTesting:",
            "scanKeynoteWindowNamesForTesting:",
            "automationCommandRunnerForTesting:",
            "automationCommandDidFinishForTesting:",
            "saveDataDidRun:"
        ].forEach { snippet in
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testTestHooksRemainObservationIgnored() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("@ObservationIgnored var testHooks = SwitcherViewModelTestHooks()"))
        XCTAssertFalse(source.contains("@ObservationIgnored var pageInterceptStartOverride"))
        XCTAssertFalse(source.contains("@ObservationIgnored var automationCommandRunnerForTesting"))
    }

    func testPageInterceptStartOverrideHookStillWorks() {
        let viewModel = makeViewModel()
        viewModel.testHooks.pageInterceptStartOverride = { true }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "pptEventTapStarted" })
    }

    func testScanOpenKeynoteFilesHookStillWorks() {
        let viewModel = makeViewModel()
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("key")
            .path
        viewModel.testHooks.scanOpenKeynoteFiles = { [path] }
        viewModel.testHooks.scanKeynoteWindowNames = { [] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.sourceURL?.path), [path])
    }

    func testScanKeynoteWindowNamesHookStillWorks() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanOpenKeynoteFiles = { [] }
        viewModel.testHooks.scanKeynoteWindowNames = { ["Opening.key", "Finale.pptx"] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening", "Finale"])
    }

    func testAutomationCommandRunnerHookStillWorks() {
        let viewModel = makeViewModel()
        var didRun = false
        viewModel.testHooks.automationCommandRunner = { _, action in
            didRun = action == "test.action"
        }

        viewModel.dispatchRuntimeFacadeAction(.automationScriptRequested(script: "return", action: "test.action"))
        waitForMainActorQueue()

        XCTAssertTrue(didRun)
    }

    func testAutomationCommandCompletionHookStillWorks() {
        let viewModel = makeViewModel()
        var didFinish = false
        viewModel.testHooks.automationCommandRunner = { _, _ in }
        viewModel.testHooks.automationCommandDidFinish = { didFinish = true }

        viewModel.dispatchRuntimeFacadeAction(.automationScriptRequested(script: "return", action: "test.action"))
        waitForMainActorQueue()

        XCTAssertTrue(didFinish)
    }

    func testPersistenceSaveDataHookStillWorks() {
        let viewModel = makeViewModel()
        var saveCount = 0
        viewModel.testHooks.saveDataDidRun = { saveCount += 1 }

        viewModel.addProgramItem(ProgramItem.agendaMarker(title: "Break"))

        XCTAssertEqual(saveCount, 1)
    }

    private func waitForMainActorQueue() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ViewModelTestHooksTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }
}
