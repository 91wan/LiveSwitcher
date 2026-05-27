import XCTest
@testable import LiveSwitcher

final class PlaybackProgressPolicyTests: XCTestCase {
    func testClampsOverrunCurrentTimeToDuration() {
        let state = PlaybackProgressPolicy.displayState(currentTime: 161, duration: 144)

        XCTAssertEqual(state.currentTime, 144)
        XCTAssertEqual(state.duration, 144)
        XCTAssertEqual(state.progress, 1)
    }

    func testClampsNegativeAndInvalidCurrentTimeToZero() {
        XCTAssertEqual(PlaybackProgressPolicy.displayState(currentTime: -2, duration: 144).currentTime, 0)
        XCTAssertEqual(PlaybackProgressPolicy.displayState(currentTime: .nan, duration: 144).currentTime, 0)
        XCTAssertEqual(PlaybackProgressPolicy.displayState(currentTime: .infinity, duration: 144).currentTime, 0)
    }

    func testUnknownDurationKeepsSafeCurrentTimeAndZeroProgress() {
        let state = PlaybackProgressPolicy.displayState(currentTime: 10, duration: nil)

        XCTAssertEqual(state.currentTime, 10)
        XCTAssertNil(state.duration)
        XCTAssertEqual(state.progress, 0)
    }

    func testInvalidDurationIsTreatedAsUnknown() {
        XCTAssertNil(PlaybackProgressPolicy.displayState(currentTime: 10, duration: 0).duration)
        XCTAssertNil(PlaybackProgressPolicy.displayState(currentTime: 10, duration: .nan).duration)
        XCTAssertNil(PlaybackProgressPolicy.displayState(currentTime: 10, duration: .infinity).duration)
    }

    func testAVPlayerAndBGMProgressUseSharedPolicy() throws {
        let coordinator = try sourceText("Engines/AVPlayerCoordinator.swift")
        let bgmStore = try sourceText("Models/BGMProgressStore.swift")

        XCTAssertTrue(coordinator.contains("PlaybackProgressPolicy.displayState"))
        XCTAssertTrue(bgmStore.contains("PlaybackProgressPolicy.displayState"))
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
