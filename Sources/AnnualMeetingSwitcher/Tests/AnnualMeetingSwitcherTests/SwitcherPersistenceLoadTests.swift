import XCTest
@testable import LiveSwitcher

final class SwitcherPersistenceLoadTests: XCTestCase {
    func testFreshLoadDefaultsAudioStrategyToFollowProgram() throws {
        let defaults = try makeDefaults()

        let state = SwitcherPersistenceStore(userDefaults: defaults).load().state

        XCTAssertEqual(state.audioStrategy, .followProgram)
    }

    func testLoadRestoresProgramItems() throws {
        let defaults = try makeDefaults()
        let video = try makeTempFile(extension: "mp4")
        defaults.set([video.path], forKey: "pushList_paths")
        defaults.set(["Opening"], forKey: "pushList_titles")
        defaults.set(["VIDEO"], forKey: "pushList_subtitles")
        defaults.set(["1700000000.0"], forKey: "pushList_scheduled_starts")
        defaults.set(["45.0"], forKey: "pushList_scheduled_durations")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(result.state.programItems.count, 1)
        XCTAssertEqual(result.state.programItems[0].title, "Opening")
        XCTAssertEqual(result.state.programItems[0].sourceURL, video)
        XCTAssertEqual(result.state.programItems[0].scheduledStartAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(result.state.programItems[0].scheduledDuration, 45)
    }

    func testLoadRestoresAgendaMarkersWithoutFileMissingSupport() throws {
        let defaults = try makeDefaults()
        defaults.set([""], forKey: "pushList_paths")
        defaults.set(["Marker"], forKey: "pushList_titles")
        defaults.set([ProgramItem.agendaMarkerSubtitle], forKey: "pushList_subtitles")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(result.state.programItems.first?.title, "Marker")
        XCTAssertTrue(result.state.programItems.first?.isAgendaMarker == true)
        XCTAssertFalse(result.supportEvents.contains { $0.kind == .programItemFileMissing })
    }

    func testLoadRestoresAgendaMarkerMissingTitleWithLocalizedFallback() throws {
        let defaults = try makeDefaults()
        defaults.set([""], forKey: "pushList_paths")
        defaults.set([ProgramItem.agendaMarkerSubtitle], forKey: "pushList_subtitles")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(result.state.programItems.first?.title, "议程标记")
        XCTAssertTrue(result.state.programItems.first?.isAgendaMarker == true)
        XCTAssertFalse(result.supportEvents.contains { $0.kind == .programItemFileMissing })
    }

    func testLoadReportsMissingProgramFiles() throws {
        let defaults = try makeDefaults()
        defaults.set(["/tmp/missing-\(UUID().uuidString).mp4"], forKey: "pushList_paths")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(result.supportEvents.map(\.kind), [.programItemFileMissing])
        XCTAssertEqual(result.supportEvents.first?.detail, "count=1")
    }

    func testLoadRestoresBGMItems() throws {
        let defaults = try makeDefaults()
        let bgm = try makeTempFile(extension: "mp3")
        defaults.set([bgm.path], forKey: "bgmList_paths")
        defaults.set([BGMCategory.award.rawValue], forKey: "bgmList_categories")
        defaults.set(["Awards"], forKey: "bgmList_titles")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(result.state.bgmItems.count, 1)
        XCTAssertEqual(result.state.bgmItems[0].title, "Awards")
        XCTAssertEqual(result.state.bgmItems[0].url, bgm)
        XCTAssertEqual(result.state.bgmItems[0].category, .award)
    }

    func testLoadReportsMissingBGMFiles() throws {
        let defaults = try makeDefaults()
        defaults.set(["/tmp/missing-\(UUID().uuidString).mp3"], forKey: "bgmList_paths")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(result.supportEvents.map(\.kind), [.bgmFileMissing])
        XCTAssertEqual(result.supportEvents.first?.detail, "count=1")
    }

    func testLoadRestoresRenderableWallpapersOnly() throws {
        let defaults = try makeDefaults()
        let good = try makeTempPNG()
        let bad = try makeTempFile(extension: "png", contents: Data("not image".utf8))
        defaults.set([good.path, bad.path], forKey: "backgroundWallpapers_paths")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(result.state.backgroundWallpapers, [good])
        XCTAssertEqual(result.supportEvents.map(\.kind), [.wallpaperFileMissing])
        XCTAssertEqual(defaults.stringArray(forKey: "backgroundWallpapers_paths"), [good.path, bad.path])
        XCTAssertTrue(result.repairs.contains(.rewriteWallpaperPaths([good.path])))
    }

    func testLoadReportsDroppedWallpapers() throws {
        let defaults = try makeDefaults()
        defaults.set(["/tmp/missing-\(UUID().uuidString).png"], forKey: "backgroundWallpapers_paths")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(result.supportEvents.first?.kind, .wallpaperFileMissing)
        XCTAssertEqual(result.supportEvents.first?.detail, "count=1")
        XCTAssertTrue(result.repairs.contains(.rewriteWallpaperPaths([])))
    }

    func testLoadRestoresActiveWallpaperFallback() throws {
        let defaults = try makeDefaults()
        let first = try makeTempPNG()
        let second = try makeTempPNG()
        defaults.set([first.path, second.path], forKey: "backgroundWallpapers_paths")
        defaults.set("/tmp/missing-\(UUID().uuidString).png", forKey: "activeWallpaper_path")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(result.state.activeWallpaperURL, first)
        XCTAssertNotEqual(defaults.string(forKey: "activeWallpaper_path"), first.path)
        XCTAssertTrue(result.repairs.contains(.setActiveWallpaperPath(first.path)))
    }

    func testLoadRestoresCornerLogoOnlyWhenRenderable() throws {
        let defaults = try makeDefaults()
        let logo = try makeTempPNG()
        defaults.set(logo.path, forKey: "cornerLogo_path")
        defaults.set(CornerLogoPosition.bottomLeft.rawValue, forKey: "cornerLogo_position")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(result.state.cornerLogoURL, logo)
        XCTAssertEqual(result.state.cornerLogoPosition, .bottomLeft)

        defaults.set("/tmp/missing-\(UUID().uuidString).png", forKey: "cornerLogo_path")
        let repaired = SwitcherPersistenceStore(userDefaults: defaults).load()
        XCTAssertNil(repaired.state.cornerLogoURL)
        XCTAssertNotNil(defaults.string(forKey: "cornerLogo_path"))
        XCTAssertTrue(repaired.repairs.contains(.removeCornerLogo))
    }

    func testLoadRestoresAudioAndConsolePreferences() throws {
        let defaults = try makeDefaults()
        defaults.set("跟随源", forKey: "audioStrategy")
        defaults.set(BGMPlayMode.sequential.rawValue, forKey: "bgmPlayMode")
        defaults.set(true, forKey: "speakerMode")
        defaults.set(true, forKey: "autoPlayNextVideoOnEnd")
        defaults.set(true, forKey: "agendaReminderEnabled")
        defaults.set(true, forKey: "showAgendaTimeline")
        defaults.set(ConsoleMode.live.rawValue, forKey: "consoleMode")
        defaults.set(ThemeOverride.light.rawValue, forKey: "themeOverride")

        let state = SwitcherPersistenceStore(userDefaults: defaults).load().state

        XCTAssertEqual(state.audioStrategy, .followSource)
        XCTAssertEqual(state.bgmPlayMode, .sequential)
        XCTAssertTrue(state.isSpeakerMode)
        XCTAssertTrue(state.autoPlayNextVideoOnEnd)
        XCTAssertTrue(state.isAgendaTimeReminderEnabled)
        XCTAssertTrue(state.showAgendaTimeline)
        XCTAssertEqual(state.consoleMode, .live)
        XCTAssertEqual(state.themeOverride, .light)
    }

    func testLoadMigratesLegacyAutoAdvancePreferenceToAgendaReminderKey() throws {
        let defaults = try makeDefaults()
        defaults.set(true, forKey: "autoAdvanceAtScheduledTime")
        XCTAssertNil(defaults.object(forKey: "agendaReminderEnabled"))

        let state = SwitcherPersistenceStore(userDefaults: defaults).load().state

        XCTAssertTrue(state.isAgendaTimeReminderEnabled)
        XCTAssertTrue(defaults.bool(forKey: "agendaReminderEnabled"))
        XCTAssertNil(defaults.object(forKey: "autoAdvanceAtScheduledTime"))
    }

    func testLoadRestoresOverlayPresetsNormalized() throws {
        let defaults = try makeDefaults()
        let lowerThirds = [
            LowerThirdPreset(id: UUID(), name: " Beta ", role: " Role Two ", organization: " Org Two ", orderIndex: 3),
            LowerThirdPreset(id: UUID(), name: "Alpha", role: " Role One ", organization: " Org One ", orderIndex: 1),
            LowerThirdPreset(id: UUID(), name: "   ", role: "Drop", organization: "Drop", orderIndex: 0)
        ]
        let countdowns = [
            CountdownPreset(id: UUID(), title: "", totalSeconds: 30, orderIndex: 4),
            CountdownPreset(id: UUID(), title: "Invalid", totalSeconds: 0, orderIndex: 0)
        ]
        let tickers = [
            TickerPreset(id: UUID(), text: " Welcome ", speedIndex: 999, orderIndex: 2),
            TickerPreset(id: UUID(), text: " ", speedIndex: 0, orderIndex: 0)
        ]
        defaults.set(try JSONEncoder().encode(lowerThirds), forKey: "overlay.presets.lowerThird.json")
        defaults.set(try JSONEncoder().encode(countdowns), forKey: "overlay.presets.countdown.json")
        defaults.set(try JSONEncoder().encode(tickers), forKey: "overlay.presets.ticker.json")

        let state = SwitcherPersistenceStore(userDefaults: defaults).load().state

        XCTAssertEqual(state.lowerThirdPresets.map(\.name), ["Alpha", "Beta"])
        XCTAssertEqual(state.lowerThirdPresets.map(\.role), ["Role One", "Role Two"])
        XCTAssertEqual(state.lowerThirdPresets.map(\.organization), ["Org One", "Org Two"])
        XCTAssertEqual(state.lowerThirdPresets.map(\.orderIndex), [0, 1])
        XCTAssertEqual(state.countdownPresets.map(\.title), [CountdownPreset.defaultTitle])
        XCTAssertEqual(state.tickerPresets.map(\.text), ["Welcome"])
        XCTAssertEqual(state.tickerPresets.first?.speedIndex, OverlaySpeedSelection.options.index(before: OverlaySpeedSelection.options.endIndex))
    }

    func testLoadMigratesLegacyLowerThirdSubtitleToOrganization() throws {
        let defaults = try makeDefaults()
        let id = UUID()
        let legacyJSON = """
        [
          {"id":"\(id.uuidString)","name":"张三","subtitle":"示例科技有限公司","orderIndex":2}
        ]
        """.data(using: .utf8)!
        defaults.set(legacyJSON, forKey: "overlay.presets.lowerThird.json")

        let state = SwitcherPersistenceStore(userDefaults: defaults).load().state

        XCTAssertEqual(state.lowerThirdPresets.count, 1)
        XCTAssertEqual(state.lowerThirdPresets[0].id, id)
        XCTAssertEqual(state.lowerThirdPresets[0].name, "张三")
        XCTAssertEqual(state.lowerThirdPresets[0].role, "")
        XCTAssertEqual(state.lowerThirdPresets[0].organization, "示例科技有限公司")
        XCTAssertEqual(state.lowerThirdPresets[0].orderIndex, 0)
    }

    func testLoadSkipsBadLowerThirdPresetWithoutDroppingValidPresets() throws {
        let defaults = try makeDefaults()
        let validID = UUID()
        let mixedJSON = """
        [
          {"id":"\(validID.uuidString)","name":"张三","role":"主持人","organization":"示例科技","orderIndex":0},
          {"id":"not-a-uuid","name":"坏数据","role":"错误","organization":"错误","orderIndex":1},
          {"id":"\(UUID().uuidString)","name":"李四","subtitle":"旧单位","orderIndex":2}
        ]
        """.data(using: .utf8)!
        defaults.set(mixedJSON, forKey: "overlay.presets.lowerThird.json")

        let state = SwitcherPersistenceStore(userDefaults: defaults).load().state

        XCTAssertEqual(state.lowerThirdPresets.map(\.name), ["张三", "李四"])
        XCTAssertEqual(state.lowerThirdPresets.map(\.role), ["主持人", ""])
        XCTAssertEqual(state.lowerThirdPresets.map(\.organization), ["示例科技", "旧单位"])
        XCTAssertEqual(state.lowerThirdPresets.map(\.orderIndex), [0, 1])
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "SwitcherPersistenceLoadTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeTempFile(extension pathExtension: String, contents: Data = Data()) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
        try contents.write(to: url)
        return url
    }

    private func makeTempPNG() throws -> URL {
        let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=")!
        return try makeTempFile(extension: "png", contents: data)
    }
}
