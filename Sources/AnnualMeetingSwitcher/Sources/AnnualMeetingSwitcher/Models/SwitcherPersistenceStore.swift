import Foundation

struct SwitcherPersistenceStore {
    let userDefaults: UserDefaults
    var now: () -> Date = Date.init

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
        saveCompanyDisplayName(state.companyDisplayName)
        if let cornerLogoURL = state.cornerLogoURL {
            userDefaults.set(cornerLogoURL.path, forKey: SwitcherPersistenceKeys.cornerLogo)
        } else {
            userDefaults.removeObject(forKey: SwitcherPersistenceKeys.cornerLogo)
        }
        saveCornerLogoVisible(state.isCornerLogoVisible && state.cornerLogoURL != nil)
        saveCornerLogoPosition(state.cornerLogoPosition)

        saveEncoded(state.lowerThirdPresets, forKey: SwitcherPersistenceKeys.lowerThirdPresets)
        saveEncoded(state.countdownPresets, forKey: SwitcherPersistenceKeys.countdownPresets)
        saveEncoded(state.tickerPresets, forKey: SwitcherPersistenceKeys.tickerPresets)
    }

    func load() -> SwitcherPersistenceLoadResult {
        var state = SwitcherPersistentState()
        var supportEvents: [LiveSupportEvent] = []
        var repairs: [SwitcherPersistenceRepair] = []

        loadProgramItems(into: &state, supportEvents: &supportEvents)
        loadBGMItems(into: &state, supportEvents: &supportEvents)
        loadWallpapers(into: &state, supportEvents: &supportEvents, repairs: &repairs)
        loadCornerLogo(into: &state, repairs: &repairs)
        loadPreferences(into: &state)
        loadOverlayPresets(into: &state)

        return SwitcherPersistenceLoadResult(
            state: state,
            supportEvents: supportEvents,
            repairs: repairs
        )
    }

    func applyRepairs(_ repairs: [SwitcherPersistenceRepair]) {
        for repair in repairs {
            switch repair {
            case let .rewriteWallpaperPaths(paths):
                userDefaults.set(paths, forKey: SwitcherPersistenceKeys.wallpapers)
            case let .setActiveWallpaperPath(path):
                userDefaults.set(path, forKey: SwitcherPersistenceKeys.activeWallpaper)
            case .removeActiveWallpaper:
                userDefaults.removeObject(forKey: SwitcherPersistenceKeys.activeWallpaper)
            case .removeCornerLogo:
                userDefaults.removeObject(forKey: SwitcherPersistenceKeys.cornerLogo)
                userDefaults.set(false, forKey: SwitcherPersistenceKeys.cornerLogoVisible)
            }
        }
    }

    func repairAudioStrategyPersistenceIfNeeded(_ strategy: AudioStrategy) {
        guard let storedValue = userDefaults.string(forKey: SwitcherPersistenceKeys.audioStrategy),
              storedValue != strategy.rawValue,
              AudioStrategy(persistedValue: storedValue) == strategy
        else { return }

        saveAudioStrategy(strategy)
    }

    func saveConsoleMode(_ mode: ConsoleMode) {
        userDefaults.set(mode.rawValue, forKey: SwitcherPersistenceKeys.consoleMode)
    }

    func saveThemeOverride(_ theme: ThemeOverride) {
        userDefaults.set(theme.rawValue, forKey: SwitcherPersistenceKeys.themeOverride)
    }

    func saveCompanyDisplayName(_ displayName: String) {
        let normalized = BrandingDisplayNamePolicy.normalizedDisplayName(from: displayName)
        guard BrandingDisplayNamePolicy.validationMessage(for: normalized) == nil else { return }
        if normalized.isEmpty {
            userDefaults.removeObject(forKey: SwitcherPersistenceKeys.companyDisplayName)
        } else {
            userDefaults.set(normalized, forKey: SwitcherPersistenceKeys.companyDisplayName)
        }
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

    func saveAgendaReminderEnabled(_ isEnabled: Bool) {
        userDefaults.set(isEnabled, forKey: SwitcherPersistenceKeys.agendaReminderEnabled)
        userDefaults.removeObject(forKey: SwitcherPersistenceKeys.legacyAutoAdvanceAtScheduledTime)
    }

    func saveAgendaTimeReminderEnabled(_ isEnabled: Bool) {
        saveAgendaReminderEnabled(isEnabled)
    }

    func saveShowAgendaTimeline(_ isEnabled: Bool) {
        userDefaults.set(isEnabled, forKey: SwitcherPersistenceKeys.showAgendaTimeline)
    }

    func saveCornerLogoVisible(_ isVisible: Bool) {
        userDefaults.set(isVisible, forKey: SwitcherPersistenceKeys.cornerLogoVisible)
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
            supportEvents.append(LiveSupportEvent(timestamp: now(), kind: .programItemFileMissing, detail: "count=\(missingCount)"))
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
            supportEvents.append(LiveSupportEvent(timestamp: now(), kind: .bgmFileMissing, detail: "count=\(missingCount)"))
        }
    }

    private func loadWallpapers(
        into state: inout SwitcherPersistentState,
        supportEvents: inout [LiveSupportEvent],
        repairs: inout [SwitcherPersistenceRepair]
    ) {
        guard let paths = userDefaults.stringArray(forKey: SwitcherPersistenceKeys.wallpapers) else { return }

        state.backgroundWallpapers = paths.compactMap { path -> URL? in
            let url = URL(fileURLWithPath: path)
            return WallpaperImagePolicy.isRenderableImage(url: url) ? url : nil
        }
        let droppedCount = paths.count - state.backgroundWallpapers.count
        if droppedCount > 0 {
            supportEvents.append(LiveSupportEvent(timestamp: now(), kind: .wallpaperFileMissing, detail: "count=\(droppedCount)"))
            repairs.append(.rewriteWallpaperPaths(state.backgroundWallpapers.map(\.path)))
        }

        if let activePath = userDefaults.string(forKey: SwitcherPersistenceKeys.activeWallpaper) {
            let activeURL = URL(fileURLWithPath: activePath)
            state.activeWallpaperURL = state.backgroundWallpapers.contains(activeURL) ? activeURL : state.backgroundWallpapers.first
            if let activeWallpaperURL = state.activeWallpaperURL {
                if activeWallpaperURL.path != activePath {
                    repairs.append(.setActiveWallpaperPath(activeWallpaperURL.path))
                }
            } else {
                repairs.append(.removeActiveWallpaper)
            }
        } else {
            state.activeWallpaperURL = state.backgroundWallpapers.first
            if let activeWallpaperURL = state.activeWallpaperURL {
                repairs.append(.setActiveWallpaperPath(activeWallpaperURL.path))
            }
        }
    }

    private func loadCornerLogo(into state: inout SwitcherPersistentState, repairs: inout [SwitcherPersistenceRepair]) {
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
                repairs.append(.removeCornerLogo)
            }
        }
        if userDefaults.object(forKey: SwitcherPersistenceKeys.cornerLogoVisible) != nil {
            state.isCornerLogoVisible = userDefaults.bool(forKey: SwitcherPersistenceKeys.cornerLogoVisible)
                && state.cornerLogoURL != nil
        } else {
            state.isCornerLogoVisible = state.cornerLogoURL != nil
        }
    }

    private func loadPreferences(into state: inout SwitcherPersistentState) {
        if let companyName = userDefaults.string(forKey: SwitcherPersistenceKeys.companyDisplayName) {
            let normalized = BrandingDisplayNamePolicy.normalizedDisplayName(from: companyName)
            if BrandingDisplayNamePolicy.validationMessage(for: normalized) == nil {
                state.companyDisplayName = normalized
            }
        }
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
        if userDefaults.object(forKey: SwitcherPersistenceKeys.agendaReminderEnabled) != nil {
            state.isAgendaTimeReminderEnabled = userDefaults.bool(forKey: SwitcherPersistenceKeys.agendaReminderEnabled)
        } else if userDefaults.object(forKey: SwitcherPersistenceKeys.legacyAutoAdvanceAtScheduledTime) != nil {
            let migratedValue = userDefaults.bool(forKey: SwitcherPersistenceKeys.legacyAutoAdvanceAtScheduledTime)
            state.isAgendaTimeReminderEnabled = migratedValue
            saveAgendaReminderEnabled(migratedValue)
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
        if let lowerThirdPresetData = userDefaults.data(forKey: SwitcherPersistenceKeys.lowerThirdPresets) {
            state.lowerThirdPresets = LowerThirdPreset.normalized(
                Self.decodeLowerThirdPresetsLossy(from: lowerThirdPresetData)
            )
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

    private static func decodeLowerThirdPresetsLossy(from data: Data) -> [LowerThirdPreset] {
        let decoder = JSONDecoder()
        if let presets = try? decoder.decode([LowerThirdPreset].self, from: data) {
            return presets
        }
        guard
            let rawItems = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return []
        }

        return rawItems.compactMap { item in
            guard JSONSerialization.isValidJSONObject(item),
                  let itemData = try? JSONSerialization.data(withJSONObject: item)
            else {
                return nil
            }
            return try? decoder.decode(LowerThirdPreset.self, from: itemData)
        }
    }
}
