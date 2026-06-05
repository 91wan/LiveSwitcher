import XCTest
@testable import LiveSwitcher

final class ViewModelModelExtractionTests: XCTestCase {
    func testProgramItemIsNotDeclaredInViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("struct ProgramItem:"))
    }

    func testBGMItemIsNotDeclaredInViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("struct BGMItem:"))
    }

    func testBGMPlayModeIsNotDeclaredInViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("enum BGMPlayMode:"))
    }

    func testProgramItemInitializerBehaviorUnchanged() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/show.mp4")
        let start = Date(timeIntervalSince1970: 100)

        let item = ProgramItem(
            id: id,
            title: "Opening",
            subtitle: "Video",
            sourceURL: url,
            scheduledStartAt: start,
            scheduledDuration: 30
        )

        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.title, "Opening")
        XCTAssertEqual(item.subtitle, "Video")
        XCTAssertEqual(item.sourceURL, url)
        XCTAssertEqual(item.scheduledStartAt, start)
        XCTAssertEqual(item.scheduledDuration, 30)
    }

    func testBGMItemInitializerBehaviorUnchanged() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/walk-in.mp3")

        let item = BGMItem(id: id, title: "Walk-in", url: url, category: .entrance)

        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.title, "Walk-in")
        XCTAssertEqual(item.url, url)
        XCTAssertEqual(item.category, .entrance)
    }

    func testBGMPlayModeCasesUnchanged() {
        XCTAssertEqual(BGMPlayMode.allCases, [.loopAll, .loopOne, .sequential])
        XCTAssertEqual(BGMPlayMode.loopAll.rawValue, "列表循环播放")
        XCTAssertEqual(BGMPlayMode.loopOne.rawValue, "单曲循环")
        XCTAssertEqual(BGMPlayMode.sequential.rawValue, "顺序播放")
    }

    func testRuntimeStillCompilesAgainstProgramItemAndBGMItem() {
        let program = ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/video.mp4"))
        let bgm = BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
        var state = LiveRuntimeState()

        state.program.items = [program]
        state.bgm.items = [bgm]
        state.bgm.playMode = .sequential

        XCTAssertEqual(state.program.items.first, program)
        XCTAssertEqual(state.bgm.items.first, bgm)
        XCTAssertEqual(state.bgm.playMode, .sequential)
    }

    func testModelFilesExist() throws {
        XCTAssertNotNil(try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ProgramItem.swift"))
        XCTAssertNotNil(try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/BGMItem.swift"))
        XCTAssertNotNil(try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/BGMPlayMode.swift"))
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }
}
