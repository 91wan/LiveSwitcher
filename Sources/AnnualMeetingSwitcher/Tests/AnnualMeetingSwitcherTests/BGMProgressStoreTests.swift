import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMProgressStoreTests: XCTestCase {
    func testTimerIntervalIsOperatorFriendlyTenFPS() {
        XCTAssertEqual(BGMProgressStore.updateInterval, 0.1, accuracy: 0.0001)
    }

    func testUpdateCalculatesProgressAndDuration() {
        let store = BGMProgressStore()

        store.update(currentTime: 25, duration: 100)

        XCTAssertEqual(store.currentTime, 25)
        XCTAssertEqual(store.duration, 100)
        XCTAssertEqual(store.progress, 0.25, accuracy: 0.0001)
    }

    func testUpdateClampsProgressAndHandlesUnknownDuration() {
        let store = BGMProgressStore()

        store.update(currentTime: 125, duration: 100)
        XCTAssertEqual(store.progress, 1, accuracy: 0.0001)

        store.update(currentTime: 8, duration: 0)
        XCTAssertEqual(store.currentTime, 8)
        XCTAssertNil(store.duration)
        XCTAssertEqual(store.progress, 0)
    }

    func testResetClearsProgressState() {
        let store = BGMProgressStore()
        store.update(currentTime: 12, duration: 60)

        store.reset()

        XCTAssertEqual(store.progress, 0)
        XCTAssertEqual(store.currentTime, 0)
        XCTAssertNil(store.duration)
    }

    func testViewModelNoLongerPublishesBGMProgressTriplet() throws {
        let source = try sourceText("ViewModel.swift")

        XCTAssertFalse(source.contains("@Published var bgmProgress: Double"))
        XCTAssertFalse(source.contains("@Published var bgmCurrentTime: Double"))
        XCTAssertFalse(source.contains("@Published var bgmDuration: Double?"))
        XCTAssertFalse(source.contains("withTimeInterval: 1.0 / 30.0"))
        XCTAssertTrue(source.contains("let bgmProgressStore = BGMProgressStore()"))
        XCTAssertTrue(source.contains("withTimeInterval: BGMProgressStore.updateInterval"))
    }

    func testBGMPlaylistProgressBarObservesDedicatedStore() throws {
        let source = try sourceText("Views/BGMPlaylistPanel.swift")

        XCTAssertTrue(source.contains("BGMProgressBar(progressStore: viewModel.bgmProgressStore"))
        XCTAssertTrue(source.contains("@ObservedObject var progressStore: BGMProgressStore"))
        XCTAssertFalse(source.contains("get: { viewModel.bgmProgress }"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
