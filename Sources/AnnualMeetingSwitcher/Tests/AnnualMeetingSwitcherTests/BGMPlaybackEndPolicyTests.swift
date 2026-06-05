import XCTest
@testable import LiveSwitcher

final class BGMPlaybackEndPolicyTests: XCTestCase {
    func testTreatsOverrunNonLoopingPlaybackAsFinished() {
        XCTAssertTrue(BGMPlaybackEndPolicy.shouldTreatAsFinished(
            isPlaying: true,
            playMode: .loopAll,
            currentTime: 161,
            duration: 144
        ))
    }

    func testDoesNotTreatLoopOneOverrunAsFinished() {
        XCTAssertFalse(BGMPlaybackEndPolicy.shouldTreatAsFinished(
            isPlaying: true,
            playMode: .loopOne,
            currentTime: 161,
            duration: 144
        ))
    }

    func testDoesNotFinishWhenPlaybackIsStoppedOrDurationUnknown() {
        XCTAssertFalse(BGMPlaybackEndPolicy.shouldTreatAsFinished(
            isPlaying: false,
            playMode: .loopAll,
            currentTime: 161,
            duration: 144
        ))
        XCTAssertFalse(BGMPlaybackEndPolicy.shouldTreatAsFinished(
            isPlaying: true,
            playMode: .loopAll,
            currentTime: 161,
            duration: nil
        ))
    }

    func testFinishesAtDurationBoundaryButNotBefore() {
        XCTAssertFalse(BGMPlaybackEndPolicy.shouldTreatAsFinished(
            isPlaying: true,
            playMode: .loopAll,
            currentTime: 143.9,
            duration: 144
        ))
        XCTAssertTrue(BGMPlaybackEndPolicy.shouldTreatAsFinished(
            isPlaying: true,
            playMode: .loopAll,
            currentTime: 144,
            duration: 144
        ))
    }

    func testNumberOfLoopsMatchesSelectedPlayMode() {
        XCTAssertEqual(BGMPlaybackEndPolicy.numberOfLoops(for: .loopOne), -1)
        XCTAssertEqual(BGMPlaybackEndPolicy.numberOfLoops(for: .loopAll), 0)
        XCTAssertEqual(BGMPlaybackEndPolicy.numberOfLoops(for: .sequential), 0)
    }

    func testViewModelUsesEndPolicyFromProgressTimerAndNewPlayers() throws {
        let source = try sourceText("ViewModel+BGMRuntimePlayback.swift")
        let controls = try sourceText("ViewModel+BGMControls.swift")
        let updateBody = try XCTUnwrap(source.functionBody(named: "updateBGMProgress"))
        let prepareBody = try XCTUnwrap(source.functionBody(named: "prepareRuntimeBGM"))

        XCTAssertTrue(updateBody.contains("finishBGMIfProgressReachedEnd"))
        XCTAssertTrue(source.contains("BGMPlaybackEndPolicy.shouldTreatAsFinished"))
        XCTAssertTrue(source.contains("bgmAudioPlayer?.delegate = nil"))
        XCTAssertTrue(prepareBody.contains("BGMPlaybackEndPolicy.numberOfLoops(for: runtime.state.bgm.playMode)"))
        XCTAssertTrue(controls.contains(".operatorSelectedBGMPlayMode(bgmPlayMode)"))
    }

    func testBGMPauseFadeTasksAreGenerationGuarded() throws {
        let source = try sourceText("ViewModel+BGMRuntimePlayback.swift")
        let facade = try sourceText("ViewModel+RuntimeFacade.swift")

        XCTAssertTrue(source.contains("func prepareRuntimeBGM(_ item: BGMItem, generation: Int)"))
        XCTAssertTrue(source.contains("setActiveRuntimeBGMCallbackIdentity(item: item, generation: generation)"))
        XCTAssertTrue(facade.contains("validatedRuntimeBGMCallbackGeneration()"))
        XCTAssertTrue(source.contains("self.currentBGMTransitionGenerationForRuntime() == generation"))
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

private extension String {
    func functionBody(named functionName: String) -> String? {
        guard let nameRange = range(of: "func \(functionName)") else { return nil }
        guard let openingBrace = self[nameRange.lowerBound...].firstIndex(of: "{") else { return nil }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            let character = self[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}
