import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeLibraryBoundaryTests: XCTestCase {
    func testBGMItemsLibraryStillOwnedByViewModel() {
        let viewModel = makeViewModel()
        let item = bgmItem("Library")

        viewModel.bgmItems = [item]
        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.bgmItems, [item])
        XCTAssertEqual(viewModel.runtime.state.bgm.items, [item])
    }

    func testRuntimeDoesNotMutateBGMItemsOnPlaybackToggle() {
        let viewModel = makeViewModel()
        let first = bgmItem("First")
        let second = bgmItem("Second")
        viewModel.bgmItems = [first, second]

        viewModel.toggleBGM(first)

        XCTAssertEqual(viewModel.bgmItems, [first, second])
    }

    func testRemovingNonCurrentBGMDoesNotAffectRuntimePlayback() {
        let viewModel = makeViewModel()
        let first = bgmItem("First")
        let second = bgmItem("Second")
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)

        viewModel.removeBGMItem(second)

        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, first.id)
        XCTAssertTrue(viewModel.runtime.state.bgm.isPlaying)
    }

    func testRemovingCurrentBGMLibraryItemStopsRuntimePlayback() {
        let viewModel = makeViewModel()
        let first = bgmItem("First")
        viewModel.bgmItems = [first]
        viewModel.toggleBGM(first)

        viewModel.removeBGMItem(first)

        XCTAssertEqual(viewModel.bgmItems, [])
        XCTAssertFalse(viewModel.runtime.state.bgm.isPlaying)
    }

    func testBGMImportStillUsesViewModelDuplicatePolicy() throws {
        let source = try sourceText("ViewModel.swift")

        XCTAssertTrue(source.contains("BGMDuplicatePolicy"))
    }

    func testBGMReorderStillSavesLibraryInViewModel() throws {
        let source = try sourceText("ViewModel.swift")
        let body = try functionBody(named: "moveBGMItems(from source", in: source)

        XCTAssertTrue(body.contains("bgmItems.move"))
        XCTAssertTrue(body.contains("saveData()"))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "BGMRuntimeLibraryBoundaryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }

    private func bgmItem(_ title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }

    private func functionBody(named name: String, in source: String) throws -> String {
        guard let start = source.range(of: "func \(name)") else {
            XCTFail("Function \(name) not found")
            return ""
        }
        guard let bodyStart = source[start.lowerBound...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var index = bodyStart
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 { return String(source[start.lowerBound...index]) }
            }
            index = source.index(after: index)
        }
        return ""
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent(relativePath)
        ]
        if let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return url
        }
        return candidates[0]
    }
}
