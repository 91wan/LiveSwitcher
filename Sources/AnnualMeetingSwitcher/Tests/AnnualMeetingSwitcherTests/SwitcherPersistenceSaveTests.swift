import XCTest
@testable import LiveSwitcher

final class SwitcherPersistenceSaveTests: XCTestCase {
    func testSaveProgramItemsPreservesPathsTitlesSubtitlesAndSchedule() throws {
        let defaults = try makeDefaults()
        let store = SwitcherPersistenceStore(userDefaults: defaults)
        let mediaURL = URL(fileURLWithPath: "/tmp/opening.mp4")
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let media = ProgramItem(title: "Opening", subtitle: "VIDEO", sourceURL: mediaURL, scheduledStartAt: start, scheduledDuration: 42)
        let marker = ProgramItem.agendaMarker(title: "Marker", scheduledStartAt: start.addingTimeInterval(60))

        store.save(SwitcherPersistentState(programItems: [media, marker]))

        XCTAssertEqual(defaults.stringArray(forKey: "pushList_paths"), [mediaURL.path, ""])
        XCTAssertEqual(defaults.stringArray(forKey: "pushList_titles"), ["Opening", "Marker"])
        XCTAssertEqual(defaults.stringArray(forKey: "pushList_subtitles"), ["VIDEO", ProgramItem.agendaMarkerSubtitle])
        XCTAssertEqual(defaults.stringArray(forKey: "pushList_scheduled_starts"), [String(start.timeIntervalSince1970), String(start.addingTimeInterval(60).timeIntervalSince1970)])
        XCTAssertEqual(defaults.stringArray(forKey: "pushList_scheduled_durations"), ["42.0", "900.0"])
    }

    func testSaveBGMItemsPreservesPathsCategoriesAndTitles() throws {
        let defaults = try makeDefaults()
        let store = SwitcherPersistenceStore(userDefaults: defaults)
        let first = BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"), category: .entrance)
        let second = BGMItem(title: "Awards", url: URL(fileURLWithPath: "/tmp/awards.mp3"), category: .award)

        store.save(SwitcherPersistentState(bgmItems: [first, second]))

        XCTAssertEqual(defaults.stringArray(forKey: "bgmList_paths"), [first.url.path, second.url.path])
        XCTAssertEqual(defaults.stringArray(forKey: "bgmList_categories"), [BGMCategory.entrance.rawValue, BGMCategory.award.rawValue])
        XCTAssertEqual(defaults.stringArray(forKey: "bgmList_titles"), ["Walk-in", "Awards"])
    }

    func testSaveWallpapersPreservesActiveWallpaper() throws {
        let defaults = try makeDefaults()
        let store = SwitcherPersistenceStore(userDefaults: defaults)
        let first = URL(fileURLWithPath: "/tmp/first.png")
        let second = URL(fileURLWithPath: "/tmp/second.png")

        store.save(SwitcherPersistentState(backgroundWallpapers: [first, second], activeWallpaperURL: second))

        XCTAssertEqual(defaults.stringArray(forKey: "backgroundWallpapers_paths"), [first.path, second.path])
        XCTAssertEqual(defaults.string(forKey: "activeWallpaper_path"), second.path)
    }

    func testSaveCornerLogoPreservesPosition() throws {
        let defaults = try makeDefaults()
        let store = SwitcherPersistenceStore(userDefaults: defaults)
        let logo = URL(fileURLWithPath: "/tmp/logo.png")

        store.save(SwitcherPersistentState(cornerLogoURL: logo, cornerLogoPosition: .bottomLeft))

        XCTAssertEqual(defaults.string(forKey: "cornerLogo_path"), logo.path)
        XCTAssertEqual(defaults.string(forKey: "cornerLogo_position"), CornerLogoPosition.bottomLeft.rawValue)
    }

    func testSaveLowerThirdCountdownTickerPresets() throws {
        let defaults = try makeDefaults()
        let store = SwitcherPersistenceStore(userDefaults: defaults)
        let lowerThird = LowerThirdPreset(id: UUID(), name: "Host", subtitle: "MC", orderIndex: 0)
        let countdown = CountdownPreset(id: UUID(), title: "Start", totalSeconds: 30, orderIndex: 0)
        let ticker = TickerPreset(id: UUID(), text: "Welcome", speedIndex: 1, orderIndex: 0)

        store.save(SwitcherPersistentState(lowerThirdPresets: [lowerThird], countdownPresets: [countdown], tickerPresets: [ticker]))

        XCTAssertEqual(try decoded([LowerThirdPreset].self, defaults: defaults, key: "overlay.presets.lowerThird.json"), [lowerThird])
        XCTAssertEqual(try decoded([CountdownPreset].self, defaults: defaults, key: "overlay.presets.countdown.json"), [countdown])
        XCTAssertEqual(try decoded([TickerPreset].self, defaults: defaults, key: "overlay.presets.ticker.json"), [ticker])
    }

    func testSaveRemovesActiveWallpaperWhenNil() throws {
        let defaults = try makeDefaults()
        defaults.set("/tmp/old.png", forKey: "activeWallpaper_path")

        SwitcherPersistenceStore(userDefaults: defaults).save(SwitcherPersistentState(activeWallpaperURL: nil))

        XCTAssertNil(defaults.string(forKey: "activeWallpaper_path"))
    }

    func testSaveRemovesCornerLogoWhenNil() throws {
        let defaults = try makeDefaults()
        defaults.set("/tmp/old-logo.png", forKey: "cornerLogo_path")

        SwitcherPersistenceStore(userDefaults: defaults).save(SwitcherPersistentState(cornerLogoURL: nil))

        XCTAssertNil(defaults.string(forKey: "cornerLogo_path"))
    }

    func testSaveAudioStrategyWritesLegacyKey() throws {
        let defaults = try makeDefaults()

        SwitcherPersistenceStore(userDefaults: defaults).saveAudioStrategy(.bgmOnly)

        XCTAssertEqual(defaults.string(forKey: "audioStrategy"), AudioStrategy.bgmOnly.rawValue)
    }

    func testSaveConsoleModeWritesLegacyKey() throws {
        let defaults = try makeDefaults()

        SwitcherPersistenceStore(userDefaults: defaults).saveConsoleMode(.live)

        XCTAssertEqual(defaults.string(forKey: "consoleMode"), ConsoleMode.live.rawValue)
    }

    func testSaveThemeOverrideWritesLegacyKey() throws {
        let defaults = try makeDefaults()

        SwitcherPersistenceStore(userDefaults: defaults).saveThemeOverride(.light)

        XCTAssertEqual(defaults.string(forKey: "themeOverride"), ThemeOverride.light.rawValue)
    }

    func testSaveSpeakerModeWritesLegacyKey() throws {
        let defaults = try makeDefaults()

        SwitcherPersistenceStore(userDefaults: defaults).saveSpeakerMode(true)

        XCTAssertTrue(defaults.bool(forKey: "speakerMode"))
    }

    func testSaveBGMPlayModeWritesLegacyKey() throws {
        let defaults = try makeDefaults()

        SwitcherPersistenceStore(userDefaults: defaults).saveBGMPlayMode(.sequential)

        XCTAssertEqual(defaults.string(forKey: "bgmPlayMode"), BGMPlayMode.sequential.rawValue)
    }

    func testSaveAutoPlayNextVideoOnEndWritesLegacyKey() throws {
        let defaults = try makeDefaults()

        SwitcherPersistenceStore(userDefaults: defaults).saveAutoPlayNextVideoOnEnd(true)

        XCTAssertTrue(defaults.bool(forKey: "autoPlayNextVideoOnEnd"))
    }

    func testSaveAutoAdvanceAtScheduledTimeWritesLegacyKey() throws {
        let defaults = try makeDefaults()

        SwitcherPersistenceStore(userDefaults: defaults).saveAutoAdvanceAtScheduledTime(true)

        XCTAssertTrue(defaults.bool(forKey: "autoAdvanceAtScheduledTime"))
    }

    func testSaveShowAgendaTimelineWritesLegacyKey() throws {
        let defaults = try makeDefaults()

        SwitcherPersistenceStore(userDefaults: defaults).saveShowAgendaTimeline(true)

        XCTAssertTrue(defaults.bool(forKey: "showAgendaTimeline"))
    }

    func testSaveCornerLogoPositionWritesLegacyKey() throws {
        let defaults = try makeDefaults()

        SwitcherPersistenceStore(userDefaults: defaults).saveCornerLogoPosition(.bottomRight)

        XCTAssertEqual(defaults.string(forKey: "cornerLogo_position"), CornerLogoPosition.bottomRight.rawValue)
    }

    @MainActor
    func testRuntimePersistencePortStillWritesSpecificKeys() throws {
        let suiteName = "SwitcherPersistenceSaveTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)

        viewModel.audioStrategy = .bgmOnly
        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedBGMPlayMode(.sequential))
        viewModel.cornerLogoPosition = .bottomLeft

        XCTAssertEqual(defaults.string(forKey: "audioStrategy"), AudioStrategy.bgmOnly.rawValue)
        XCTAssertEqual(defaults.string(forKey: "bgmPlayMode"), BGMPlayMode.sequential.rawValue)
        XCTAssertEqual(defaults.string(forKey: "cornerLogo_position"), CornerLogoPosition.bottomLeft.rawValue)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "SwitcherPersistenceSaveTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func decoded<T: Decodable>(_ type: T.Type, defaults: UserDefaults, key: String) throws -> T {
        let data = try XCTUnwrap(defaults.data(forKey: key))
        return try JSONDecoder().decode(type, from: data)
    }
}
