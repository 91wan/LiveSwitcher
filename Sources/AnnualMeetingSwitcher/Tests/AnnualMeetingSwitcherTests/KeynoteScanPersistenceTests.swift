import XCTest
@testable import LiveSwitcher

@MainActor
final class KeynoteScanPersistenceTests: XCTestCase {
    func testScanningThreeFileBackedDocsSavesOnce() {
        let viewModel = makeViewModel()
        let paths = [
            "/tmp/keynote-a/Opening.key",
            "/tmp/keynote-b/Awards.key",
            "/tmp/keynote-c/Finale.pptx"
        ]
        var saveCount = 0
        viewModel.scanOpenKeynoteFilesForTesting = { paths }
        viewModel.scanKeynoteWindowNamesForTesting = { [] }
        viewModel.saveDataDidRun = { saveCount += 1 }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.count, 3)
        XCTAssertEqual(saveCount, 1)
    }

    func testScanningThreeActiveWindowNamesSavesOnce() {
        let viewModel = makeViewModel()
        var saveCount = 0
        viewModel.scanOpenKeynoteFilesForTesting = { [] }
        viewModel.scanKeynoteWindowNamesForTesting = { ["Opening.key", "Awards.key", "Finale.pptx"] }
        viewModel.saveDataDidRun = { saveCount += 1 }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening", "Awards", "Finale"])
        XCTAssertEqual(saveCount, 1)
    }

    func testScanningExistingItemsSavesZeroTimes() {
        let viewModel = makeViewModel()
        let path = "/tmp/keynote-existing/Opening.key"
        viewModel.addProgramItem(ProgramItem(
            title: "Opening",
            subtitle: "KEY",
            sourceURL: URL(fileURLWithPath: path)
        ))
        var saveCount = 0
        viewModel.scanOpenKeynoteFilesForTesting = { [path] }
        viewModel.scanKeynoteWindowNamesForTesting = { [] }
        viewModel.saveDataDidRun = { saveCount += 1 }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.count, 1)
        XCTAssertEqual(saveCount, 0)
    }

    func testDuplicateFileBackedDocsAreSkippedWithinOneScan() {
        let viewModel = makeViewModel()
        let path = "/tmp/keynote-duplicate/Opening.key"
        var saveCount = 0
        viewModel.scanOpenKeynoteFilesForTesting = { [path, path, path] }
        viewModel.scanKeynoteWindowNamesForTesting = { [] }
        viewModel.saveDataDidRun = { saveCount += 1 }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.count, 1)
        XCTAssertEqual(saveCount, 1)
    }

    func testSameTitleDifferentFileURLsAreAllowedForFileBackedDocs() {
        let viewModel = makeViewModel()
        let paths = [
            "/tmp/keynote-first/Opening.key",
            "/tmp/keynote-second/Opening.key"
        ]
        var saveCount = 0
        viewModel.scanOpenKeynoteFilesForTesting = { paths }
        viewModel.scanKeynoteWindowNamesForTesting = { [] }
        viewModel.saveDataDidRun = { saveCount += 1 }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.count, 2)
        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening", "Opening"])
        XCTAssertEqual(saveCount, 1)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "KeynoteScanPersistenceTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
    }
}
