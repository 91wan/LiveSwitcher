import XCTest
@testable import LiveSwitcher

final class PersistencePortContractTests: XCTestCase {
    func testPersistencePortHasNoDefaultSpecificSaveImplementations() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift"
        )

        XCTAssertFalse(source.contains("extension PersistencePort"))
        XCTAssertFalse(source.contains("func saveConsoleMode(_ mode: ConsoleMode) {"))
    }

    func testClosurePersistencePortImplementsEveryPersistenceMethod() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeClosurePorts.swift"
        )

        [
            "func save()",
            "func saveConsoleMode(_ mode: ConsoleMode)",
            "func saveThemeOverride(_ theme: ThemeOverride)",
            "func saveAudioStrategy(_ strategy: AudioStrategy)",
            "func saveSpeakerMode(_ isEnabled: Bool)",
            "func saveBGMPlayMode(_ playMode: BGMPlayMode)",
            "func saveAutoPlayNextVideoOnEnd(_ isEnabled: Bool)",
            "func saveAutoAdvanceAtScheduledTime(_ isEnabled: Bool)",
            "func saveShowAgendaTimeline(_ isEnabled: Bool)",
            "func saveCornerLogoPosition(_ position: CornerLogoPosition)"
        ].forEach { snippet in
            XCTAssertTrue(source.contains(snippet), snippet)
        }
    }

    func testSpecificSaveDoesNotFallBackToGenericSave() {
        let port = ClosurePersistencePort()
        var genericSaveCount = 0
        var specificEvents: [String] = []
        port.saveHandler = { genericSaveCount += 1 }
        port.saveConsoleModeHandler = { specificEvents.append("console:\($0.rawValue)") }
        port.saveThemeOverrideHandler = { specificEvents.append("theme:\($0.rawValue)") }
        port.saveAudioStrategyHandler = { specificEvents.append("strategy:\($0.rawValue)") }
        port.saveSpeakerModeHandler = { specificEvents.append("speaker:\($0)") }
        port.saveBGMPlayModeHandler = { specificEvents.append("bgm:\($0.rawValue)") }
        port.saveAutoPlayNextVideoOnEndHandler = { specificEvents.append("autoNext:\($0)") }
        port.saveAutoAdvanceAtScheduledTimeHandler = { specificEvents.append("autoAdvance:\($0)") }
        port.saveShowAgendaTimelineHandler = { specificEvents.append("timeline:\($0)") }
        port.saveCornerLogoPositionHandler = { specificEvents.append("corner:\($0.rawValue)") }

        port.saveConsoleMode(.live)
        port.saveThemeOverride(.dark)
        port.saveAudioStrategy(.mixed)
        port.saveSpeakerMode(true)
        port.saveBGMPlayMode(.sequential)
        port.saveAutoPlayNextVideoOnEnd(true)
        port.saveAutoAdvanceAtScheduledTime(true)
        port.saveShowAgendaTimeline(true)
        port.saveCornerLogoPosition(.bottomLeft)

        XCTAssertEqual(genericSaveCount, 0)
        XCTAssertEqual(specificEvents.count, 9)
    }
}
