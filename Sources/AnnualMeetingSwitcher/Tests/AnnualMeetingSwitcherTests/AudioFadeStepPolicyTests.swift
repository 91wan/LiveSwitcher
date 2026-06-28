import XCTest
@testable import LiveSwitcher

final class AudioFadeStepPolicyTests: XCTestCase {
    func testShortFadesStillHaveEnoughStepsToAvoidAbruptTail() {
        XCTAssertEqual(AudioFadeStepPolicy.stepCount(duration: 0.1), AudioFadeStepPolicy.minimumSteps)
    }

    func testLiveAudioFadeUsesSmoothThirtyHzSteps() {
        XCTAssertEqual(AudioFadeStepPolicy.stepCount(duration: 1.0), 30)
        XCTAssertEqual(AudioFadeStepPolicy.stepCount(duration: 2.0), AudioFadeStepPolicy.maximumSteps)
    }

    func testInvalidDurationsFallBackToSingleImmediateStep() {
        XCTAssertEqual(AudioFadeStepPolicy.stepCount(duration: 0), 1)
        XCTAssertEqual(AudioFadeStepPolicy.stepCount(duration: .nan), 1)
        XCTAssertEqual(AudioFadeStepPolicy.stepCount(duration: .infinity), 1)
    }

    func testViewModelUsesSharedFadeStepPolicy() throws {
        let source = try String(contentsOf: sourceURL("BGMPlayback/BGMPlayerFade.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("AudioFadeStepPolicy.stepCount(duration: duration)"))
        XCTAssertFalse(source.contains("let steps = 20"))
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
