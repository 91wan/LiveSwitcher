import XCTest

final class ViewModelProgramMediaTransportExtractionTests: XCTestCase {
    func testProgramMediaTransportMethodsAreNotDeclaredInProgramActivationFile() throws {
        let source = try activationSource()

        for forbidden in mediaTransportSnippets {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testProgramMediaTransportMethodsLiveInProgramMediaTransportExtension() throws {
        let source = try transportSource()

        XCTAssertTrue(source.contains("extension SwitcherViewModel"))
        for required in mediaTransportSnippets {
            XCTAssertTrue(source.contains(required), required)
        }
    }

    func testProgramMediaTransportMethodsAreNotDeclaredInProgramQueueFile() throws {
        let source = try programQueueSource()

        for forbidden in mediaTransportSnippets {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testProgramMediaTransportMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        for forbidden in mediaTransportSnippets {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    private var mediaTransportSnippets: [String] {
        [
            "func toggleMainVideoPlayback(",
            "func togglePause(",
            "func seekProgramItemToStart(",
            "func restartCurrentMediaFromBeginning(",
            "func seekProgramItemToEnd(",
            "programItemSupportsSeeking"
        ]
    }

    private func activationSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift")
    }

    private func transportSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramMediaTransport.swift")
    }

    private func programQueueSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift")
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }
}
