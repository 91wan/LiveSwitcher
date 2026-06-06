import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelPresentationAutomationBehaviorTests: XCTestCase {
    func testScanAndAddKeynoteWindowsUsesPresentationQueryResultBuilder() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "scanAndAddKeynoteWindows"))

        XCTAssertTrue(body.contains("PresentationQueryResultBuilder.makeProgramItems("))
        XCTAssertFalse(body.contains("ProgramItem("))
        XCTAssertFalse(body.contains("itemsToAdd.append"))
        XCTAssertFalse(body.contains("alreadyAdded"))
        XCTAssertFalse(body.contains("KeynoteController.cleanedDocumentTitle"))
    }

    func testScanAndAddKeynoteWindowsStillAddsOpenKeynoteFiles() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { ["Ignored.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
        XCTAssertEqual(viewModel.programItems.map(\.sourceURL?.path), ["/tmp/show/Opening.key"])
    }

    func testScanAndAddKeynoteWindowsStillAddsWindowNamesWhenNoFiles() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { ["Opening.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { [] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
        XCTAssertEqual(viewModel.programItems.map(\.sourceURL), [nil])
    }

    func testScanAndAddKeynoteWindowsStillDedupesExistingFiles() {
        let viewModel = makeViewModel()
        viewModel.addProgramItem(ProgramItem(
            title: "Opening",
            subtitle: "KEY",
            sourceURL: URL(fileURLWithPath: "/tmp/show/Opening.key")
        ))
        viewModel.testHooks.scanKeynoteWindowNames = { [] }
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.count, 1)
    }

    func testScanAndAddKeynoteWindowsStillDedupesExistingWindowNames() {
        let viewModel = makeViewModel()
        viewModel.addProgramItem(ProgramItem(title: "Opening", subtitle: "KEY (活动)", sourceURL: nil))
        viewModel.testHooks.scanKeynoteWindowNames = { ["Opening.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { [] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.count, 1)
    }

    func testScanAndAddKeynoteWindowsStillNoopsOnScanFailure() {
        let viewModel = makeViewModel()
        viewModel.testHooks.presentationQueryService = PresentationQueryService(
            runAppleScript: { _, _ in
                throw AppleScriptError.executionFailed(action: "keynote.scan.windows", message: "failed")
            },
            scanOpenKeynoteFiles: { ["/tmp/show/Opening.key"] }
        )

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertTrue(viewModel.programItems.isEmpty)
    }

    func testScanFailureStillRecordsSupportAndAutomationNotice() {
        let viewModel = makeViewModel()
        viewModel.testHooks.presentationQueryService = PresentationQueryService(
            runAppleScript: { _, _ in
                throw AppleScriptError.executionFailed(action: "keynote.scan.windows", message: "permission denied")
            },
            scanOpenKeynoteFiles: { [] }
        )

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .appleScriptFailed })
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "keynote.scan.windows")
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ViewModelPresentationAutomationBehaviorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }
}
