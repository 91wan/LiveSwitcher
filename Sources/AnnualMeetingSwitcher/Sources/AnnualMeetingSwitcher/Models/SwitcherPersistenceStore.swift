import Foundation

struct SwitcherPersistenceStore {
    let userDefaults: UserDefaults

    func save(_ state: SwitcherPersistentState) {
        saveAudioStrategy(state.audioStrategy)
        saveSpeakerMode(state.isSpeakerMode)
        saveBGMPlayMode(state.bgmPlayMode)

        let persistentProgramItems = ProgramQueueStore.persistentProgramItems(from: state.programItems)
        userDefaults.set(persistentProgramItems.map { $0.sourceURL?.path ?? "" }, forKey: SwitcherPersistenceKeys.pushList)
        userDefaults.set(persistentProgramItems.map(\.title), forKey: SwitcherPersistenceKeys.pushListTitles)
        userDefaults.set(persistentProgramItems.map(\.subtitle), forKey: SwitcherPersistenceKeys.pushListSubtitles)
        userDefaults.set(ProgramQueueStore.encodedScheduleStarts(for: persistentProgramItems), forKey: SwitcherPersistenceKeys.pushListScheduledStarts)
        userDefaults.set(ProgramQueueStore.encodedScheduleDurations(for: persistentProgramItems), forKey: SwitcherPersistenceKeys.pushListScheduledDurations)

        userDefaults.set(state.bgmItems.map { $0.url.path }, forKey: SwitcherPersistenceKeys.bgmList)
        userDefaults.set(state.bgmItems.map { $0.category.rawValue }, forKey: SwitcherPersistenceKeys.bgmListCategories)
        userDefaults.set(state.bgmItems.map(\.title), forKey: SwitcherPersistenceKeys.bgmListTitles)

        userDefaults.set(state.backgroundWallpapers.map(\.path), forKey: SwitcherPersistenceKeys.wallpapers)
        if let activeWallpaperURL = state.activeWallpaperURL {
            userDefaults.set(activeWallpaperURL.path, forKey: SwitcherPersistenceKeys.activeWallpaper)
        } else {
            userDefaults.removeObject(forKey: SwitcherPersistenceKeys.activeWallpaper)
        }
        if let cornerLogoURL = state.cornerLogoURL {
            userDefaults.set(cornerLogoURL.path, forKey: SwitcherPersistenceKeys.cornerLogo)
        } else {
            userDefaults.removeObject(forKey: SwitcherPersistenceKeys.cornerLogo)
        }
        saveCornerLogoPosition(state.cornerLogoPosition)

        saveEncoded(state.lowerThirdPresets, forKey: SwitcherPersistenceKeys.lowerThirdPresets)
        saveEncoded(state.countdownPresets, forKey: SwitcherPersistenceKeys.countdownPresets)
        saveEncoded(state.tickerPresets, forKey: SwitcherPersistenceKeys.tickerPresets)
    }

    func load() -> SwitcherPersistenceLoadResult {
        var state = SwitcherPersistentState()
        var supportEvents: [LiveSupportEvent] = []
        var repairedWallpaperPaths: [String]?
        var repairedActiveWallpaperURL: URL?

        loadProgramItems(into: &state, supportEvents: &supportEvents)
        loadBGMItems(into: &state, supportEvents: &supportEvents)
        loadWallpapers(into: &state, supportEvents: &supportEvents, repairedWallpaperPaths: &repairedWallpaperPaths, repairedActiveWallpaperURL: &repairedActiveWallpaperURL)
        loadCornerLogo(into: &state)
        loadPreferences(into: &state)
        loadOverlayPresets(into: &state)

        return SwitcherPersistenceLoadResult(
            state: state,
            supportEvents: supportEvents,
            repairedWallpaperPaths: repairedWallpaperPaths,
            repairedActiveWallpaperURL: repairedActiveWallpaperURL,
            shouldRewriteWallpaperPaths: repairedWallpaperPaths != nil
        )
    }

    func saveConsoleMode(_ mode: ConsoleMode) {
        userDefaults.set(mode.rawValue, forKey: SwitcherPersistenceKeys.consoleMode)
    }

    func saveThemeOverride(_ theme: ThemeOverride) {
        userDefaults.set(theme.rawValue, forKey: SwitcherPersistenceKeys.themeOverride)
    }

    func saveAudioStrategy(_ strategy: AudioStrategy) {
        userDefaults.set(strategy.rawValue, forKey: SwitcherPersistenceKeys.audioStrategy)
    }

    func saveSpeakerMode(_ isEnabled: Bool) {
        userDefaults.set(isEnabled, forKey: SwitcherPersistenceKeys.speakerMode)
    }

    func saveBGMPlayMode(_ playMode: BGMPlayMode) {
        userDefaults.set(playMode.rawValue, forKey: SwitcherPersistenceKeys.bgmPlayMode)
    }

    func saveAutoPlayNextVideoOnEnd(_ isEnabled: Bool) {
        userDefaults.set(isEnabled, forKey: SwitcherPersistenceKeys.autoPlayNextVideoOnEnd)
    }

    func saveAutoAdvanceAtScheduledTime(_ isEnabled: Bool) {
        userDefaults.set(isEnabled, forKey: SwitcherPersistenceKeys.autoAdvanceAtScheduledTime)
    }

    func saveShowAgendaTimeline(_ isEnabled: Bool) {
        userDefaults.set(isEnabled, forKey: SwitcherPersistenceKeys.showAgendaTimeline)
    }

    func saveCornerLogoPosition(_ position: CornerLogoPosition) {
        userDefaults.set(position.rawValue, forKey: SwitcherPersistenceKeys.cornerLogoPosition)
    }

    private func loadProgramItems(into state: inout SwitcherPersistentState, supportEvents: inout [LiveSupportEvent]) {
        guard let paths = userDefaults.stringArray(forKey: SwitcherPersistenceKeys.pushList) else { return }

        let titles = userDefaults.stringArray(forKey: SwitcherPersistenceKeys.pushListTitles) ?? []
        let subtitles = userDefaults.stringArray(forKey: SwitcherPersistenceKeys.pushListSubtitles) ?? []
        let scheduledStarts = userDefaults.stringArray(forKey: SwitcherPersistenceKeys.pushListScheduledStarts) ?? []
        let scheduledDurations = userDefaults.stringArray(forKey: SwitcherPersistenceKeys.pushListScheduledDurations) ?? []
        let missingCount = paths.enumerated().filter { index, path in
            if path.isEmpty,
               index < subtitles.count,
               ProgramItem.isAgendaMarkerSubtitle(subtitles[index]) {
                return false
            }
            return !FileManager.default.fileExists(atPath: path)
        }.count
        if missingCount > 0 {
            supportEvents.append(LiveSupportEvent(timestamp: Date(), kind: .programItemFileMissing, detail: "count=\(missingCount)"))
        }
        state.programItems = ProgramQueueStore.restoredProgramItems(
            paths: paths,
            titles: titles,
            subtitles: subtitles,
            scheduledStarts: scheduledStarts,
            scheduledDurations: scheduledDurations
        )
    }

    private func loadBGMItems(into state: inout SwitcherPersistentState, supportEvents: inout [LiveSupportEvent]) {
        guard let paths = userDefaults.stringArray(forKey: SwitcherPersistenceKeys.bgmList) else { return }

        let categories = userDefaults.stringArray(forKey: SwitcherPersistenceKeys.bgmListCategories) ?? []
        let titles = userDefaults.stringArray(forKey: SwitcherPersistenceKeys.bgmListTitles) ?? []
        var missingCount = 0
        state.bgmItems = paths.enumerated().compactMap { index, path in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                missingCount += 1
                return nil
            }
            let categoryRaw = index < categories.count ? categories[index] : BGMCategory.warmUp.rawValue
            let category = BGMCategory(rawValue: categoryRaw) ?? .warmUp
            let title = index < titles.count ? titles[index] : url.deletingPathExtension().lastPathComponent
            return BGMItem(title: title, url: url, category: category)
        }
        if missingCount > 0 {
            supportEvents.append(LiveSupportEvent(timestamp: Date(), kind: .bgmFileMissing, detail: "count=\(missingCount)"))
        }
    }

    private func loadWallpapers(
        into state: inout SwitcherPersistentState,
        supportEvents: inout [LiveSupportEvent],
        repairedWallpaperPaths: inout [String]?,
        repairedActiveWallpaperURL: inout URL?
    ) {
        guard let paths = userDefaults.stringArray(forKey: SwitcherPersistenceKeys.wallpapers) else { return }

        state.backgroundWallpapers = paths.compactMap { path -> URL? in
            let url = URL(fileURLWithPath: path)
            return WallpaperImagePolicy.isRenderableImage(url: url) ? url : nil
        }
        let droppedCount = paths.count - state.backgroundWallpapers.count
        if droppedCount > 0 {
            supportEvents.append(LiveSupportEvent(timestamp: Date(), kind: .wallpaperFileMissing, detail: "count=\(droppedCount)"))
            repairedWallpaperPaths = state.backgroundWallpapers.map(\.path)
            userDefaults.set(repairedWallpaperPaths, forKey: SwitcherPersistenceKeys.wallpapers)
        }

        if let activePath = userDefaults.string(forKey: SwitcherPersistenceKeys.activeWallpaper) {
            let activeURL = URL(fileURLWithPath: activePath)
            state.activeWallpaperURL = state.backgroundWallpapers.contains(activeURL) ? activeURL : state.backgroundWallpapers.first
        } else {
            state.activeWallpaperURL = state.backgroundWallpapers.first
        }
        repairedActiveWallpaperURL = state.activeWallpaperURL
        if let activeWallpaperURL = state.activeWallpaperURL {
            userDefaults.set(activeWallpaperURL.path, forKey: SwitcherPersistenceKeys.activeWallpaper)
        } else {
            userDefaults.removeObject(forKey: SwitcherPersistenceKeys.activeWallpaper)
        }
    }

    private func loadCornerLogo(into state: inout SwitcherPersistentState) {
        if let rawPosition = userDefaults.string(forKey: SwitcherPersistenceKeys.cornerLogoPosition),
           let position = CornerLogoPosition(rawValue: rawPosition) {
            state.cornerLogoPosition = position
        }
        if let logoPath = userDefaults.string(forKey: SwitcherPersistenceKeys.cornerLogo) {
            let logoURL = URL(fileURLWithPath: logoPath)
            if WallpaperImagePolicy.isRenderableImage(url: logoURL) {
                state.cornerLogoURL = logoURL
            } else {
                state.cornerLogoURL = nil
                userDefaults.removeObject(forKey: SwitcherPersistenceKeys.cornerLogo)
            }
        }
    }

    private func loadPreferences(into state: inout SwitcherPersistentState) {
        if let storedAudioStrategy = userDefaults.string(forKey: SwitcherPersistenceKeys.audioStrategy),
           let audioStrategy = AudioStrategy(persistedValue: storedAudioStrategy) {
            state.audioStrategy = audioStrategy
        }
        if let rawPlayMode = userDefaults.string(forKey: SwitcherPersistenceKeys.bgmPlayMode),
           let storedPlayMode = BGMPlayMode(rawValue: rawPlayMode) {
            state.bgmPlayMode = storedPlayMode
        }
        if userDefaults.object(forKey: SwitcherPersistenceKeys.speakerMode) != nil {
            state.isSpeakerMode = userDefaults.bool(forKey: SwitcherPersistenceKeys.speakerMode)
        }
        if userDefaults.object(forKey: SwitcherPersistenceKeys.autoPlayNextVideoOnEnd) != nil {
            state.autoPlayNextVideoOnEnd = userDefaults.bool(forKey: SwitcherPersistenceKeys.autoPlayNextVideoOnEnd)
        }
        if userDefaults.object(forKey: SwitcherPersistenceKeys.autoAdvanceAtScheduledTime) != nil {
            state.autoAdvanceAtScheduledTime = userDefaults.bool(forKey: SwitcherPersistenceKeys.autoAdvanceAtScheduledTime)
        }
        if userDefaults.object(forKey: SwitcherPersistenceKeys.showAgendaTimeline) != nil {
            state.showAgendaTimeline = userDefaults.bool(forKey: SwitcherPersistenceKeys.showAgendaTimeline)
        }
        if let rawConsoleMode = userDefaults.string(forKey: SwitcherPersistenceKeys.consoleMode),
           let storedConsoleMode = ConsoleMode(rawValue: rawConsoleMode) {
            state.consoleMode = storedConsoleMode
        }
        if let rawTheme = userDefaults.string(forKey: SwitcherPersistenceKeys.themeOverride),
           let storedTheme = ThemeOverride(rawValue: rawTheme) {
            state.themeOverride = storedTheme
        }
    }

    private func loadOverlayPresets(into state: inout SwitcherPersistentState) {
        if let lowerThirdPresetData = userDefaults.data(forKey: SwitcherPersistenceKeys.lowerThirdPresets),
           let storedPresets = try? JSONDecoder().decode([LowerThirdPreset].self, from: lowerThirdPresetData) {
            state.lowerThirdPresets = LowerThirdPreset.normalized(storedPresets)
        }
        if let countdownPresetData = userDefaults.data(forKey: SwitcherPersistenceKeys.countdownPresets),
           let storedPresets = try? JSONDecoder().decode([CountdownPreset].self, from: countdownPresetData) {
            state.countdownPresets = CountdownPreset.normalized(storedPresets)
        }
        if let tickerPresetData = userDefaults.data(forKey: SwitcherPersistenceKeys.tickerPresets),
           let storedPresets = try? JSONDecoder().decode([TickerPreset].self, from: tickerPresetData) {
            state.tickerPresets = TickerPreset.normalized(storedPresets)
        }
    }

    private func saveEncoded<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        userDefaults.set(data, forKey: key)
    }
}
