import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeRetiredPlayerCleanupTests: XCTestCase {
    func testRetiredAVAudioPlayerCleanupRunsEvenAfterGenerationAdvances() {
        let coordinator = BGMRuntimeCleanupCoordinator()
        let retired = FakeBGMRuntimeCleanupHandle()
        coordinator.currentGeneration = 1

        coordinator.currentGeneration = 2
        coordinator.releaseRetiredPlayer(retired)

        XCTAssertTrue(retired.didStop)
    }

    func testRetiredAVAudioPlayerCleanupDoesNotTouchCurrentPlayer() {
        let coordinator = BGMRuntimeCleanupCoordinator()
        let current = FakeBGMRuntimeCleanupHandle(volume: 0.7)
        let retired = FakeBGMRuntimeCleanupHandle(volume: 0.3)
        coordinator.currentPlayer = current

        coordinator.fadeRetiredPlayerVolume(retired, to: 0)
        coordinator.releaseRetiredPlayer(retired)

        XCTAssertEqual(current.volume, 0.7)
        XCTAssertFalse(current.didStop)
        XCTAssertEqual(retired.volume, 0)
        XCTAssertTrue(retired.didStop)
    }

    func testRetiredFallbackCleanupRunsEvenAfterGenerationAdvances() {
        let coordinator = BGMRuntimeCleanupCoordinator()
        let retired = FakeBGMRuntimeCleanupHandle(volume: 0.5)
        let token = coordinator.trackRetiredFallback(retired)
        coordinator.currentGeneration = 1

        coordinator.currentGeneration = 2
        coordinator.cleanupRetiredFallback(retired, token: token)

        XCTAssertTrue(retired.didPause)
        XCTAssertTrue(retired.didClear)
        XCTAssertFalse(coordinator.hasRetiredFallback(token))
    }

    func testRetiredFallbackCleanupDoesNotTouchCurrentFallbackPlayer() {
        let coordinator = BGMRuntimeCleanupCoordinator()
        let current = FakeBGMRuntimeCleanupHandle(volume: 0.8)
        let retired = FakeBGMRuntimeCleanupHandle(volume: 0.4)
        coordinator.currentFallbackPlayer = current
        let token = coordinator.trackRetiredFallback(retired)

        coordinator.cleanupRetiredFallback(retired, token: token)

        XCTAssertEqual(current.volume, 0.8)
        XCTAssertFalse(current.didPause)
        XCTAssertFalse(current.didClear)
        XCTAssertEqual(retired.volume, 0)
        XCTAssertTrue(retired.didPause)
        XCTAssertTrue(retired.didClear)
    }

    func testRapidBGM_A_B_C_StopsRetiredAAndB() {
        let coordinator = BGMRuntimeCleanupCoordinator()
        let first = FakeBGMRuntimeCleanupHandle()
        let second = FakeBGMRuntimeCleanupHandle()
        let third = FakeBGMRuntimeCleanupHandle()
        coordinator.currentGeneration = 1
        coordinator.currentPlayer = first

        coordinator.currentPlayer = second
        coordinator.currentGeneration = 2
        coordinator.currentPlayer = third
        coordinator.currentGeneration = 3
        coordinator.releaseRetiredPlayer(first)
        coordinator.releaseRetiredPlayer(second)

        XCTAssertTrue(first.didStop)
        XCTAssertTrue(second.didStop)
    }

    func testRapidBGM_A_B_C_LeavesOnlyCActive() {
        let coordinator = BGMRuntimeCleanupCoordinator()
        let first = FakeBGMRuntimeCleanupHandle()
        let second = FakeBGMRuntimeCleanupHandle()
        let third = FakeBGMRuntimeCleanupHandle()
        coordinator.currentPlayer = third

        coordinator.releaseRetiredPlayer(first)
        coordinator.releaseRetiredPlayer(second)

        XCTAssertFalse(third.didStop)
        XCTAssertTrue(first.didStop)
        XCTAssertTrue(second.didStop)
    }

    func testCurrentBGMVolumeFadeIsGenerationGuarded() {
        let coordinator = BGMRuntimeCleanupCoordinator()
        let current = FakeBGMRuntimeCleanupHandle(volume: 1)
        coordinator.currentGeneration = 2
        coordinator.currentPlayer = current

        coordinator.fadeCurrentPlayerVolume(to: 0, generation: 1)

        XCTAssertEqual(current.volume, 1)
    }

    func testRetiredBGMVolumeFadeIsNotSkippedByNewGeneration() {
        let coordinator = BGMRuntimeCleanupCoordinator()
        let retired = FakeBGMRuntimeCleanupHandle(volume: 1)
        coordinator.currentGeneration = 3

        coordinator.fadeRetiredPlayerVolume(retired, to: 0)

        XCTAssertEqual(retired.volume, 0)
    }

    func testReleaseRetiredBGMPlayerAfterFadeDoesNotGuardOnCurrentGeneration() throws {
        let source = try sourceText("BGMPlayback/BGMPlayerFade.swift")
        let body = try functionBody(named: "releaseRetiredBGMPlayerAfterFade", in: source)

        XCTAssertFalse(body.contains("runtime.state.bgm.generation"))
        XCTAssertFalse(body.contains("bgmTransitionGeneration == generation"))
    }

    func testCurrentBGMFadeHelperDoesGuardOnGeneration() throws {
        let source = try sourceText("BGMPlayback/BGMPlayerFade.swift")
        let body = try functionBody(named: "fadeCurrentBGMPlayerVolume", in: source)

        XCTAssertTrue(body.contains("runtime.state.bgm.generation"))
        XCTAssertTrue(body.contains("generation"))
    }

    private func functionBody(named name: String, in source: String) throws -> String {
        guard let start = source.range(of: "func \(name)") ?? source.range(of: "private func \(name)") else {
            XCTFail("Function \(name) not found")
            return ""
        }
        guard let bodyStart = source[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("Function \(name) body not found")
            return ""
        }
        var depth = 0
        var index = bodyStart
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[start.lowerBound...index])
                }
            }
            index = source.index(after: index)
        }
        XCTFail("Function \(name) body was not closed")
        return ""
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) -> URL {
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

private final class FakeBGMRuntimeCleanupHandle: BGMRuntimeCleanupHandle {
    var volume: Float
    private(set) var didStop = false
    private(set) var didPause = false
    private(set) var didClear = false

    init(volume: Float = 1) {
        self.volume = volume
    }

    func stop() {
        didStop = true
    }

    func pause() {
        didPause = true
    }

    func clear() {
        didClear = true
    }
}
