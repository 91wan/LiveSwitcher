import XCTest
@testable import LiveSwitcher

final class AudioRuntimeReducerExtractionTests: XCTestCase {
    func testAudioRuntimeReducerFileExists() throws {
        _ = try audioReducerSource()
    }

    func testAudioRuntimeReducerOwnsOperatorMutationLogic() throws {
        let source = try audioReducerSource()

        XCTAssertTrue(source.contains("static func selectStrategy"))
        XCTAssertTrue(source.contains("static func changeMasterVolume"))
        XCTAssertTrue(source.contains("static func changeMediaVolume"))
        XCTAssertTrue(source.contains("static func changeBGMVolume"))
        XCTAssertTrue(source.contains("static func changeMasterMute"))
        XCTAssertTrue(source.contains("static func changeMediaMute"))
        XCTAssertTrue(source.contains("static func changeBGMMute"))
        XCTAssertTrue(source.contains("static func changeBGMTakeover"))
        XCTAssertTrue(source.contains("static func toggleSpeakerMode"))
        XCTAssertTrue(source.contains("static func setSpeakerMode"))
    }

    func testAudioRuntimeReducerOwnsRoutingHelpers() throws {
        let source = try audioReducerSource()

        XCTAssertTrue(source.contains("internal static func recalculateAudio"))
        XCTAssertTrue(source.contains("private static func initializeRoutingContextIfNeeded"))
        XCTAssertTrue(source.contains("internal static func syncRoutingContextFromMirrorState"))
        XCTAssertTrue(source.contains("internal static func applyFacadeSnapshot"))
    }

    func testLiveRuntimeReducerDelegatesAudioActions() throws {
        let source = try liveReducerSource()

        XCTAssertTrue(source.contains("AudioRuntimeReducer.selectStrategy"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.changeMasterVolume"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.changeMediaVolume"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.changeBGMVolume"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.changeMasterMute"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.changeMediaMute"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.changeBGMMute"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.changeBGMTakeover"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.toggleSpeakerMode"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.setSpeakerMode"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.applyFacadeSnapshot"))
    }

    func testLiveRuntimeReducerNoLongerDeclaresAudioHelpers() throws {
        let source = try liveReducerSource()

        XCTAssertFalse(source.contains("internal static func recalculateAudio"))
        XCTAssertFalse(source.contains("initializeAudioRoutingContextIfNeeded"))
        XCTAssertFalse(source.contains("internal static func syncAudioRoutingContextFromMirrorState"))
        XCTAssertFalse(source.contains("private static func applyAudioFacadeSnapshot"))
    }

    func testDomainReducersCallAudioRuntimeReducerHelpers() throws {
        for path in [
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/MediaRuntimeReducer.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/BGMRuntimeReducer.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/PanicRuntimeReducer.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/ProgramSelectionRuntimeReducer.swift"
        ] {
            let source = try repositorySource(path)

            XCTAssertTrue(source.contains("AudioRuntimeReducer."), path)
            XCTAssertFalse(source.contains("LiveRuntimeReducer.recalculateAudio"), path)
            XCTAssertFalse(source.contains("LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState"), path)
        }
    }

    func testArchitectureDocsNoLongerMarkAudioReducerAsFutureWork() throws {
        let docs = try repositorySource("docs/architecture/runtime-ownership.md")

        XCTAssertTrue(docs.localizedStandardContains("AudioRuntimeReducer"))
        XCTAssertFalse(docs.contains("AudioRuntimeReducer extraction remains future work"))
        XCTAssertFalse(docs.contains("dedicated `AudioRuntimeReducer` extraction is planned as future work"))
    }

    private func audioReducerSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/AudioRuntimeReducer.swift")
    }

    private func liveReducerSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")
    }
}
