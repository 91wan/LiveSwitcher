import XCTest
@testable import LiveSwitcher

final class BGMCategorySelectionStateTests: XCTestCase {
    func testLiveDockAutoSyncsToCurrentTrackCategory() {
        let current = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)
        var state = BGMCategorySelectionState(selectedCategory: .warmUp)

        state.syncWithCurrentItem(current, allowsAutoSync: true)

        XCTAssertEqual(state.selectedCategory, .award)
    }

    func testManualCategorySelectionIsNotOverwrittenBySameCurrentTrackRefresh() {
        let current = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)
        var state = BGMCategorySelectionState(selectedCategory: .warmUp)

        state.syncWithCurrentItem(current, allowsAutoSync: true)
        state.selectCategory(.ambient)
        state.syncWithCurrentItem(current, allowsAutoSync: true)

        XCTAssertEqual(state.selectedCategory, .ambient)
    }

    func testNewCurrentTrackCanResyncAfterManualSelection() {
        let award = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)
        let exit = BGMItem(title: "Exit", url: URL(fileURLWithPath: "/tmp/exit.mp3"), category: .exit)
        var state = BGMCategorySelectionState(selectedCategory: .warmUp)

        state.syncWithCurrentItem(award, allowsAutoSync: true)
        state.selectCategory(.ambient)
        state.syncWithCurrentItem(exit, allowsAutoSync: true)

        XCTAssertEqual(state.selectedCategory, .exit)
    }

    func testFullLibraryDoesNotAutoSyncCategory() {
        let current = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)
        var state = BGMCategorySelectionState(selectedCategory: .warmUp)

        state.syncWithCurrentItem(current, allowsAutoSync: false)

        XCTAssertEqual(state.selectedCategory, .warmUp)
    }

    @MainActor
    func testAudioLibraryCategorySelectionLivesInViewModel() throws {
        let suiteName = "LiveSwitcher.BGMCategorySelectionStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        let panelSource = try bgmPlaylistSurfaceText(filePath: #filePath)

        viewModel.bgmLibraryCategorySelection.selectCategory(.award)

        XCTAssertEqual(viewModel.bgmLibraryCategorySelection.selectedCategory, .award)
        XCTAssertFalse(panelSource.contains("@State private var categorySelection"))
        XCTAssertTrue(panelSource.contains("viewModel.bgmLibraryCategorySelection"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
