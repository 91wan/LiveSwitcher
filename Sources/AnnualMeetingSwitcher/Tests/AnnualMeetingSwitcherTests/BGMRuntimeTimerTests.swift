import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeTimerTests: XCTestCase {
    func testStartBGMTimerStoresActiveGeneration() {
        let viewModel = makeViewModel()

        viewModel.startBGMTimer(generation: 4)

        XCTAssertEqual(viewModel.activeBGMTimerGenerationForTesting, 4)
        XCTAssertTrue(viewModel.bgmProgressTimerForTesting?.isValid == true)
    }

    func testStopBGMTimerIgnoresStaleGeneration() {
        let viewModel = makeViewModel()
        viewModel.startBGMTimer(generation: 4)

        viewModel.stopBGMTimer(generation: 3)

        XCTAssertEqual(viewModel.activeBGMTimerGenerationForTesting, 4)
        XCTAssertTrue(viewModel.bgmProgressTimerForTesting?.isValid == true)
    }

    func testStopBGMTimerStopsCurrentGeneration() {
        let viewModel = makeViewModel()
        viewModel.startBGMTimer(generation: 4)

        viewModel.stopBGMTimer(generation: 4)

        XCTAssertNil(viewModel.activeBGMTimerGenerationForTesting)
        XCTAssertNil(viewModel.bgmProgressTimerForTesting)
    }

    func testTimerCallbackDispatchesProgressWithActiveGeneration() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        let generation = viewModel.runtime.state.bgm.generation

        viewModel.dispatchRuntimeBGMProgressCallback(time: 5, duration: 10)

        XCTAssertEqual(viewModel.runtime.state.bgm.generation, generation)
        XCTAssertEqual(viewModel.bgmProgress, 0.5, accuracy: 0.0001)
    }

    func testTimerCallbackIgnoredAfterGenerationChanges() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        viewModel.toggleBGM(second)

        viewModel.stopBGMTimer(generation: 1)

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testNoArgumentStartBGMTimerIsPrivateOrRemoved() throws {
        let source = try sourceText("ViewModel+BGMRuntimePlayback.swift")

        XCTAssertFalse(source.contains("\n    func startBGMTimer()"))
    }

    func testRuntimeOwnedPathsUseGenerationBoundStartTimer() throws {
        let source = try sourceText("ViewModel+RuntimeWiring.swift")
        let wiring = try substring(
            in: source,
            from: "ports.bgmTimerPort.startHandler",
            to: "ports.audioRoutingPort.applyHandler"
        )

        XCTAssertFalse(wiring.contains("startBGMTimer()"))
        XCTAssertTrue(wiring.contains("startBGMTimer(generation: generation)"))
    }

    func testRuntimeOwnedPathsUseGenerationBoundStopTimer() throws {
        let source = try sourceText("ViewModel+RuntimeWiring.swift")
        let wiring = try substring(
            in: source,
            from: "ports.bgmTimerPort.stopHandler",
            to: "ports.audioRoutingPort.applyHandler"
        )

        XCTAssertFalse(wiring.contains("stopBGMTimer()"))
        XCTAssertTrue(wiring.contains("stopBGMTimer(generation: generation)"))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "BGMRuntimeTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }

    private func bgmItem(title: String = "Walk-in") -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }

    private func substring(in source: String, from startPattern: String, to endPattern: String) throws -> String {
        guard let start = source.range(of: startPattern),
              let end = source.range(of: endPattern, range: start.upperBound..<source.endIndex)
        else {
            XCTFail("Expected source range not found")
            return ""
        }
        return String(source[start.lowerBound..<end.lowerBound])
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
