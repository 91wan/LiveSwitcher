import XCTest
@testable import LiveSwitcher

final class BGMRuntimeReducerExtractionTests: XCTestCase {
    func testBGMRuntimeReducerFileExists() throws {
        _ = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/BGMRuntimeReducer.swift")
    }

    func testBGMRuntimeReducerOwnsBGMSelectionLogic() throws {
        let source = try bgmReducerSource()

        XCTAssertTrue(source.contains("static func selectBGM"))
        XCTAssertTrue(source.contains("prepareBGM"))
        XCTAssertTrue(source.contains("startBGMTimer"))
    }

    func testBGMRuntimeReducerOwnsBGMStopLogic() throws {
        let source = try bgmReducerSource()

        XCTAssertTrue(source.contains("static func stop"))
        XCTAssertTrue(source.contains("liveAudioFadeDuration"))
        XCTAssertTrue(source.contains("stopBGMTimer"))
    }

    func testBGMRuntimeReducerOwnsBGMReachedEndLogic() throws {
        let source = try bgmReducerSource()

        XCTAssertTrue(source.contains("static func reachedEnd"))
        XCTAssertTrue(source.contains("loopOne"))
        XCTAssertTrue(source.contains("sequential"))
    }

    func testBGMRuntimeReducerOwnsAdjacentSelectionLogic() throws {
        let source = try bgmReducerSource()

        XCTAssertTrue(source.contains("static func selectAdjacent"))
        XCTAssertTrue(source.contains("currentCategoryBGMItems"))
    }

    func testLiveRuntimeReducerDelegatesBGMSelection() throws {
        let source = try liveReducerSource()

        XCTAssertTrue(source.contains("BGMRuntimeReducer.selectBGM"))
    }

    func testLiveRuntimeReducerDelegatesBGMStop() throws {
        let source = try liveReducerSource()

        XCTAssertTrue(source.contains("BGMRuntimeReducer.stop"))
    }

    func testLiveRuntimeReducerDelegatesBGMReachedEnd() throws {
        let source = try liveReducerSource()

        XCTAssertTrue(source.contains("BGMRuntimeReducer.reachedEnd"))
    }

    func testLiveRuntimeReducerDelegatesBGMAdjacentSelection() throws {
        let source = try liveReducerSource()

        XCTAssertTrue(source.contains("BGMRuntimeReducer.selectAdjacent"))
    }

    func testLiveRuntimeReducerDelegatesBGMPlayMode() throws {
        let source = try liveReducerSource()

        XCTAssertTrue(source.contains("BGMRuntimeReducer.setPlayMode"))
    }

    func testLiveRuntimeReducerDoesNotDeclareSelectAdjacentBGM() throws {
        let source = try liveReducerSource()

        XCTAssertFalse(source.contains("private static func selectAdjacentBGM"))
    }

    func testLiveRuntimeReducerDoesNotDeclareCurrentCategoryBGMItems() throws {
        let source = try liveReducerSource()

        XCTAssertFalse(source.contains("private static func currentCategoryBGMItems"))
    }

    func testLiveRuntimeReducerDoesNotDeclareRestartBGM() throws {
        let source = try liveReducerSource()

        XCTAssertFalse(source.contains("private static func restartBGM"))
    }

    func testLiveRuntimeReducerDoesNotDeclareStopFinishedBGM() throws {
        let source = try liveReducerSource()

        XCTAssertFalse(source.contains("private static func stopFinishedBGM"))
    }

    func testLiveRuntimeReducerDoesNotDeclareReduceBGMReachedEnd() throws {
        let source = try liveReducerSource()

        XCTAssertFalse(source.contains("private static func reduceBGMReachedEnd"))
    }

    private func bgmReducerSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/BGMRuntimeReducer.swift")
    }

    private func liveReducerSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/BGMRuntimeActionDispatcher.swift")
    }
}
