import SwiftUI
import Combine
import AppKit
import AVFoundation
import Carbon         // V25: 翻页拦截器 CGEventTap
import ApplicationServices // V25: AXIsProcessTrusted

// MARK: - 节目单数据模型

struct ProgramItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var subtitle: String
    /// 媒体文件 URL（可选）
    var sourceURL: URL?
    var scheduledStartAt: Date?
    var scheduledDuration: TimeInterval?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        sourceURL: URL? = nil,
        scheduledStartAt: Date? = nil,
        scheduledDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.sourceURL = sourceURL
        self.scheduledStartAt = scheduledStartAt
        self.scheduledDuration = scheduledDuration
    }
}

// MARK: - BGM 播放模式

enum BGMPlayMode: String, CaseIterable {
    case loopAll   = "列表循环播放"
    case loopOne   = "单曲循环"
    case sequential = "顺序播放"
}

// MARK: - BGM 数据模型

struct BGMItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var url: URL
    var category: BGMCategory

    init(id: UUID = UUID(), title: String, url: URL, category: BGMCategory = .warmUp) {
        self.id = id
        self.title = title
        self.url = url
        self.category = category
    }
}

// MARK: - 导播台核心 ViewModel

private struct LiveMasterMeterCandidate {
    let realtimeDB: Float
    let effectiveVolume: Float

    var postFaderDB: Double {
        Double(realtimeDB) + 20 * log10(Double(effectiveVolume))
    }
}

@MainActor
final class SwitcherViewModel: ObservableObject {

    // MARK: - 主窗口导航

    @Published var selectedMainTab: MainConsoleTab = .preview
    @Published var consoleMode: ConsoleMode = .setup {
        didSet {
            userDefaults.set(consoleMode.rawValue, forKey: UDKeys.consoleMode)
        }
    }
    @Published var themeOverride: ThemeOverride = .dark {
        didSet {
            userDefaults.set(themeOverride.rawValue, forKey: UDKeys.themeOverride)
        }
    }

    // MARK: - 节目状态

    @Published var currentProgramItem: ProgramItem? {
        didSet {
            if currentProgramItem?.id != oldValue?.id {
                currentProgramSwitchedAt = currentProgramItem == nil ? nil : Date()
                applyAudioRoutingForRuntimeChange(reason: .programChanged)
            } else {
                applyAudioRoutingForRuntimeChange(reason: .programChanged)
            }
        }
    }
    @Published var currentProgramSwitchedAt: Date?
    @Published var programItems: [ProgramItem] = []
    @Published var showAgendaTimeline: Bool = false {
        didSet {
            userDefaults.set(showAgendaTimeline, forKey: UDKeys.showAgendaTimeline)
        }
    }

    // MARK: - 推流状态

    @Published var isBroadcasting: Bool = false
    @Published var broadcastSafetyNotice: String?

    // MARK: - HTML 大屏展示

    /// 当前推送到副屏 WKWebView 的 HTML 文件 URL；切换其他节目时清空
    @Published var currentHTMLURL: URL? = nil


    // MARK: - 音量控制（Fix Issue #7/#8: 所有 didSet 在 @MainActor 上安全执行）

    /// 主音量 [0.0, 1.0] - 联控 AVPlayer + BGM
    @Published var masterVolume: Double = 0.5 {
        didSet { applyMasterVolume() }
    }

    /// 媒体源音量 [0.0, 1.0]
    @Published var mediaVolume: Double = 1.0 {
        didSet { applyMasterVolume() }
    }

    /// BGM 音量 [0.0, 1.0]
    @Published var bgmVolume: Double = 0.5 {
        didSet { applyBGMVolume() }
    }

    /// Live mode mute controls are session-scoped operator actions and are not persisted.
    @Published var isMasterAudioMuted: Bool = false {
        didSet { applyAudioRoutingForRuntimeChange(reason: .operatorFaderChanged) }
    }
    @Published var isMediaAudioMuted: Bool = false {
        didSet { applyAudioRoutingForRuntimeChange(reason: .operatorFaderChanged) }
    }
    @Published var isBGMAudioMuted: Bool = false {
        didSet { applyAudioRoutingForRuntimeChange(reason: .operatorFaderChanged) }
    }

    /// 音频输出策略。默认保持“混合”，与当前已存在的实际行为一致。
    @Published var audioStrategy: AudioStrategy = .mixed {
        didSet {
            applyAudioRoutingForRuntimeChange(reason: .strategyChanged)
            userDefaults.set(audioStrategy.rawValue, forKey: UDKeys.audioStrategy)
        }
    }

    // MARK: - 转场配置

    @Published var crossfadeDuration: Double = 3.0
    var liveAudioFadeDuration: Double = 2.0
    private let speakerModeDuckedRatio: Float = 0.07

    // MARK: - 背景壁纸（多张）

    @Published var backgroundWallpapers: [URL] = []
    @Published var backgroundImage: NSImage?
    @Published var activeWallpaperURL: URL? {
        didSet {
            loadBackgroundImage(from: activeWallpaperURL)
        }
    }
    @Published var cornerLogoURL: URL? {
        didSet {
            loadCornerLogoImage(from: cornerLogoURL)
        }
    }
    @Published var cornerLogoImage: NSImage?
    @Published var cornerLogoPosition: CornerLogoPosition = .topRight {
        didSet {
            userDefaults.set(cornerLogoPosition.rawValue, forKey: UDKeys.cornerLogoPosition)
        }
    }

    // MARK: - BGM 列表

    @Published var bgmItems: [BGMItem] = []
    @Published var currentBGMItem: BGMItem?
    @Published var isBGMPlaying: Bool = false
    @Published var isBGMAudioTakeoverActive: Bool = false {
        didSet { applyAudioRoutingForRuntimeChange(reason: .strategyChanged) }
    }
    @Published var bgmPlayMode: BGMPlayMode = .loopAll
    @Published private(set) var supportEvents: [LiveSupportEvent] = []

    /// V26.3: 主讲人模式（一键压限 BGM）
    @Published var isSpeakerMode: Bool = false {
        didSet {
            userDefaults.set(isSpeakerMode, forKey: UDKeys.speakerMode)
        }
    }

    /// 视频播毕后仅自动播放队列里的紧邻下一条视频；默认关闭，避免现场自动打开演示文件。
    @Published var autoPlayNextVideoOnEnd: Bool = false {
        didSet {
            userDefaults.set(autoPlayNextVideoOnEnd, forKey: UDKeys.autoPlayNextVideoOnEnd)
        }
    }
    @Published var autoAdvanceAtScheduledTime: Bool = false {
        didSet {
            userDefaults.set(autoAdvanceAtScheduledTime, forKey: UDKeys.autoAdvanceAtScheduledTime)
        }
    }

    /// BGM 进度由独立 store 发布，避免播放计时器高频刷新整个导播台。
    let bgmProgressStore = BGMProgressStore()
    var bgmProgress: Double {
        get { bgmProgressStore.progress }
        set { bgmProgressStore.progress = BGMProgressStore.clampedProgress(newValue) }
    }
    var bgmCurrentTime: Double {
        get { bgmProgressStore.currentTime }
        set { bgmProgressStore.currentTime = max(0, newValue) }
    }
    var bgmDuration: Double? {
        get { bgmProgressStore.duration }
        set { bgmProgressStore.duration = (newValue ?? 0) > 0 ? newValue : nil }
    }
    var bgmRealtimeLevelDB: Float? = nil

    /// BGM 播放器
    var bgmAudioPlayer: AVAudioPlayer?
    var bgmFallbackPlayer: AVPlayer = AVPlayer()
    var panicPlaybackSnapshot: PanicPlaybackSnapshot?
    var panicAudioTransitionGeneration: Int = 0
    private(set) var lastAudioRoutingTransition: AudioRoutingTransition?

    // MARK: - 引擎

    let keynoteController = KeynoteController()
    let avCoordinator = AVPlayerCoordinator()

    // MARK: - 推流窗口

    private var outputWindowController: OutputWindowControlling?
    var externalScreenProvider: () -> NSScreen? = {
        SecondScreenSelector.pickExternal()
    } {
        didSet {
            refreshExternalDisplayAvailability()
        }
    }
    @Published private(set) var isExternalDisplayAvailable: Bool = false
    var outputWindowControllerFactory: () -> OutputWindowControlling = {
        OutputWindowController() as OutputWindowControlling
    }
    var keynotePresentationHandler: (URL) -> Void = { _ in }
    var pptxOpenHandler: (URL) -> Void = { _ in }
    var deckStopHandler: () -> Void = {}
    var programSeekToStartHandler: () -> Void = {}
    var programSeekToEndHandler: () -> Void = {}
    var activeDeckPresentationHandler: () -> Void = {}
    var invalidDeckHandler: (URL) -> Void = { _ in }
    var automationFailureAlertHandler: (String, String) -> Void = { title, message in
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    // MARK: - Combine / Timers

    private var cancellables = Set<AnyCancellable>()
    private var bgmProgressTimer: Timer?
    private var mediaVolumeFadeTask: Task<Void, Never>?
    private var bgmPlayerVolumeFadeTask: Task<Void, Never>?
    private var bgmFallbackVolumeFadeTask: Task<Void, Never>?
    private var bgmFallbackEndObserver: NSObjectProtocol?
    private var bgmTransitionTasks: [UUID: Task<Void, Never>] = [:]
    private var bgmTransitionGeneration: Int = 0
    var panicAudioPauseTask: Task<Void, Never>?
    private var backgroundImageLoadTask: Task<Void, Never>?
    private var cornerLogoImageLoadTask: Task<Void, Never>?
    private var systemVolumeObserver: SystemVolumeObserver?
    private var externalDisplayChangeObserver: NSObjectProtocol?
    private let supportEventLimit = 80
    private var agendaAutoAdvancePromptedItemIDs = Set<UUID>()

    // MARK: - V25: 翻页拦截器状态
    /// 翻页笔拦截开关（开启时全局拦截 PageUp/Down/左右箭头并转发给 WPS）
    @Published var isPageInterceptEnabled: Bool = false {
        didSet { applyPageInterceptState() }
    }
    private var pageInterceptEventTap: CFMachPort?
    private var pageInterceptRunLoopSource: CFRunLoopSource?
    private var pageInterceptSelfRefcon: UnsafeMutableRawPointer?
    nonisolated private let pageInterceptRuntime = PageInterceptRuntime()
    nonisolated private let wpsApplicationMonitor = WPSApplicationMonitor()

    // MARK: - V21 Fix #1: BGM Delegate（持有 delegate 防止 ARC 释放）
    let bgmDelegate = BGMPlayerDelegate()
    private let userDefaults: UserDefaults

    // MARK: - UserDefaults Keys

    private enum UDKeys {
        static let pushList = "pushList_paths"
        static let pushListScheduledStarts = "pushList_scheduled_starts"
        static let pushListScheduledDurations = "pushList_scheduled_durations"
        static let bgmList = "bgmList_paths"
        static let bgmListCategories = "bgmList_categories"
        static let wallpapers = "backgroundWallpapers_paths"
        static let activeWallpaper = "activeWallpaper_path"
        static let cornerLogo = "cornerLogo_path"
        static let cornerLogoPosition = "cornerLogo_position"
        static let audioStrategy = "audioStrategy"
        static let speakerMode = "speakerMode"
        static let autoPlayNextVideoOnEnd = "autoPlayNextVideoOnEnd"
        static let autoAdvanceAtScheduledTime = "autoAdvanceAtScheduledTime"
        static let showAgendaTimeline = "showAgendaTimeline"
        static let consoleMode = "consoleMode"
        static let themeOverride = "themeOverride"
        static let lowerThirdPresets = "overlay.presets.lowerThird.json"
        static let countdownPresets = "overlay.presets.countdown.json"
        static let tickerPresets = "overlay.presets.ticker.json"
    }

    // MARK: - Init

    init(
        loadPersistedData: Bool = true,
        enableSystemVolumeObserver: Bool = true,
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults
        self.keynotePresentationHandler = { [weak self] url in
            self?.openAndPresentKeynote(url: url)
        }
        self.pptxOpenHandler = { [weak self] url in
            self?.openPPTXWithKeynote(url: url)
        }
        self.deckStopHandler = { [weak self] in
            self?.stopDeckPresentation()
        }
        self.programSeekToStartHandler = { [weak self] in
            self?.avCoordinator.seekToBeginning()
        }
        self.programSeekToEndHandler = { [weak self] in
            self?.avCoordinator.seekToEnd()
        }
        self.activeDeckPresentationHandler = { [weak self] in
            self?.presentFrontKeynoteDocument()
        }
        self.invalidDeckHandler = { [weak self] url in
            self?.presentInvalidDeckAlert(for: url)
        }
        if loadPersistedData {
            // Fix: loadData() runs on @MainActor (since class is @MainActor), safe to call
            loadData()
        }
        setupPlayerCoordinator()
        setupExternalDisplayObserver()
        if enableSystemVolumeObserver {
            setupSystemVolumeObserver()
        }
        bgmDelegate.viewModel = self // V21 Fix #1: 绑定 delegate
    }

    deinit {
        mediaVolumeFadeTask?.cancel()
        bgmPlayerVolumeFadeTask?.cancel()
        bgmFallbackVolumeFadeTask?.cancel()
        bgmTransitionTasks.values.forEach { $0.cancel() }
        panicAudioPauseTask?.cancel()
        backgroundImageLoadTask?.cancel()
        cornerLogoImageLoadTask?.cancel()
        systemVolumeObserver?.stop()
        if let externalDisplayChangeObserver {
            NotificationCenter.default.removeObserver(externalDisplayChangeObserver)
        }
        if let bgmFallbackEndObserver {
            NotificationCenter.default.removeObserver(bgmFallbackEndObserver)
        }
        let avCoordinator = avCoordinator
        Task { @MainActor in
            avCoordinator.shutdown()
        }
    }

    // MARK: - 音量实际应用（Fix Issue #7/#8）

    func applyMasterVolume() {
        applyAudioRoutingForRuntimeChange(reason: .operatorFaderChanged)
    }

    func applyBGMVolume() {
        applyAudioRoutingForRuntimeChange(reason: .operatorFaderChanged)
    }

    func effectiveMediaOutputVolume() -> Float {
        audioRoutingOutput.media
    }

    func effectiveBGMOutputVolume() -> Float {
        audioRoutingOutput.bgm
    }

    func liveMasterMeterRealtimeDB() -> Float? {
        liveMasterMeterRealtimeCandidate()?.realtimeDB
    }

    func liveMasterMeterFallbackVolume() -> Float {
        if let candidate = liveMasterMeterRealtimeCandidate() {
            return candidate.effectiveVolume
        }

        return max(effectiveMediaOutputVolume(), effectiveBGMOutputVolume())
    }

    private func liveMasterMeterRealtimeCandidate() -> LiveMasterMeterCandidate? {
        let effectiveMedia = effectiveMediaOutputVolume()
        let effectiveBGM = (!isBGMPlaying && currentBGMItem != nil) ? 0 : effectiveBGMOutputVolume()
        guard !isPanicMode, !isMasterAudioMuted else {
            return nil
        }

        var candidates: [LiveMasterMeterCandidate] = []
        if avCoordinator.isPlaying,
           !isMediaAudioMuted,
           effectiveMedia > 0,
           let mediaDB = avCoordinator.realtimeLevelDB,
           mediaDB.isFinite {
            candidates.append(LiveMasterMeterCandidate(realtimeDB: mediaDB, effectiveVolume: effectiveMedia))
        }
        if isBGMPlaying,
           !isBGMAudioMuted,
           effectiveBGM > 0,
           let bgmDB = bgmRealtimeLevelDB,
           bgmDB.isFinite {
            candidates.append(LiveMasterMeterCandidate(realtimeDB: bgmDB, effectiveVolume: effectiveBGM))
        }

        return candidates.max { lhs, rhs in
            lhs.postFaderDB < rhs.postFaderDB
        }
    }

    private var audioRoutingOutput: AudioRoutingOutput {
        AudioRoutingEngine.output(
            for: AudioRoutingInput(
                masterVolume: masterVolume,
                mediaVolume: mediaVolume,
                bgmVolume: bgmVolume,
                audioStrategy: audioStrategy,
                isCurrentProgramMediaSource: currentProgramIsMediaSource,
                isMediaPlaying: avCoordinator.isPlaying,
                isBGMAudioTakeoverActive: isBGMAudioTakeoverActive,
                isSpeakerMode: isSpeakerMode,
                isPanicMode: isPanicMode,
                isMasterMuted: isMasterAudioMuted,
                isMediaMuted: isMediaAudioMuted,
                isBGMMuted: isBGMAudioMuted,
                speakerModeDuckedRatio: speakerModeDuckedRatio
            )
        )
    }

    func applyAudioRouting(mediaFadeDuration: Double? = nil, bgmFadeDuration: Double? = nil) {
        let effectiveMedia = effectiveMediaOutputVolume()
        if let mediaFadeDuration {
            fadeMediaVolume(to: effectiveMedia, duration: mediaFadeDuration)
        } else {
            mediaVolumeFadeTask?.cancel()
            avCoordinator.volume = effectiveMedia
        }

        let effectiveBGM = appliedBGMOutputVolume()
        if let bgmFadeDuration, bgmAudioPlayer != nil {
            fadeBGMPlayerVolume(to: effectiveBGM, duration: bgmFadeDuration)
        } else {
            bgmPlayerVolumeFadeTask?.cancel()
            bgmAudioPlayer?.volume = effectiveBGM
        }

        if let bgmFadeDuration {
            fadeBGMFallbackVolume(to: effectiveBGM, duration: bgmFadeDuration)
        } else {
            bgmFallbackVolumeFadeTask?.cancel()
            bgmFallbackPlayer.volume = effectiveBGM
        }
    }

    private func appliedBGMOutputVolume() -> Float {
        isBGMPlaying ? effectiveBGMOutputVolume() : 0
    }

    func applyAudioRoutingForRuntimeChange(reason: AudioRoutingRuntimeChangeReason) {
        let transition = AudioRoutingTransitionPolicy.transition(
            for: reason,
            liveAudioFadeDuration: liveAudioFadeDuration
        )
        lastAudioRoutingTransition = transition
        applyAudioRouting(
            mediaFadeDuration: transition.mediaFadeDuration,
            bgmFadeDuration: transition.bgmFadeDuration
        )
    }

    func resetLastAudioRoutingTransitionForTesting() {
        lastAudioRoutingTransition = nil
    }

    private func fadeMediaVolume(to targetVolume: Float, duration: Double) {
        mediaVolumeFadeTask?.cancel()
        guard duration > 0 else {
            avCoordinator.volume = targetVolume
            return
        }

        mediaVolumeFadeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let startVolume = self.avCoordinator.volume
            await self.runLinearFade(
                from: startVolume,
                to: targetVolume,
                duration: duration
            ) { [weak self] volume in
                self?.avCoordinator.volume = volume
            }
        }
    }

    private func fadeBGMFallbackVolume(to targetVolume: Float, duration: Double) {
        bgmFallbackVolumeFadeTask?.cancel()
        guard duration > 0 else {
            bgmFallbackPlayer.volume = targetVolume
            return
        }

        bgmFallbackVolumeFadeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let startVolume = self.bgmFallbackPlayer.volume
            await self.runLinearFade(
                from: startVolume,
                to: targetVolume,
                duration: duration
            ) { [weak self] volume in
                self?.bgmFallbackPlayer.volume = volume
            }
        }
    }

    private func fadeBGMPlayerVolume(to targetVolume: Float, duration: Double) {
        bgmPlayerVolumeFadeTask?.cancel()
        guard let player = bgmAudioPlayer else { return }
        guard duration > 0 else {
            player.volume = targetVolume
            return
        }

        bgmPlayerVolumeFadeTask = Task { @MainActor [weak self, weak player] in
            guard let self, let player else { return }
            let startVolume = player.volume
            await self.runLinearFade(
                from: startVolume,
                to: targetVolume,
                duration: duration
            ) { [weak player] volume in
                player?.volume = volume
            }
        }
    }

    private func fadeBGMPlayerVolume(_ player: AVAudioPlayer, to targetVolume: Float, duration: Double) {
        guard duration > 0 else {
            player.volume = targetVolume
            return
        }

        let taskID = UUID()
        bgmTransitionTasks[taskID] = Task { @MainActor [weak self, weak player] in
            defer { self?.bgmTransitionTasks[taskID] = nil }
            guard let self, let player else { return }
            let startVolume = player.volume
            await self.runLinearFade(
                from: startVolume,
                to: targetVolume,
                duration: duration
            ) { [weak player] volume in
                player?.volume = volume
            }
        }
    }

    func installBGMFallbackEndObserver(for item: AVPlayerItem) {
        removeBGMFallbackEndObserver()
        bgmFallbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bgmDidFinish()
            }
        }
    }

    func removeBGMFallbackEndObserver() {
        if let bgmFallbackEndObserver {
            NotificationCenter.default.removeObserver(bgmFallbackEndObserver)
            self.bgmFallbackEndObserver = nil
        }
    }

    private func runLinearFade(
        from startVolume: Float,
        to targetVolume: Float,
        duration: Double,
        apply: @escaping (Float) -> Void
    ) async {
        let steps = 20
        let stepDuration = UInt64((duration / Double(steps)) * 1_000_000_000)

        for step in 1...steps {
            if Task.isCancelled { return }
            let progress = Float(step) / Float(steps)
            apply(startVolume + (targetVolume - startVolume) * progress)
            try? await Task.sleep(nanoseconds: stepDuration)
        }

        if !Task.isCancelled {
            apply(targetVolume)
        }
    }

    private var currentProgramIsMediaSource: Bool {
        currentProgramItem?.sourceKind == .media
    }

    private func loadBackgroundImage(from url: URL?) {
        backgroundImageLoadTask?.cancel()
        guard let url else {
            backgroundImage = nil
            return
        }
        backgroundImage = NSImage(byReferencing: url)
        backgroundImageLoadTask = Task { @MainActor [weak self] in
            let data = await Self.imageData(from: url)
            guard !Task.isCancelled, let self, self.activeWallpaperURL == url else { return }
            self.backgroundImage = data.flatMap(NSImage.init(data:))
        }
    }

    private func loadCornerLogoImage(from url: URL?) {
        cornerLogoImageLoadTask?.cancel()
        guard let url else {
            cornerLogoImage = nil
            return
        }
        cornerLogoImage = NSImage(byReferencing: url)
        cornerLogoImageLoadTask = Task { @MainActor [weak self] in
            let data = await Self.imageData(from: url)
            guard !Task.isCancelled, let self, self.cornerLogoURL == url else { return }
            self.cornerLogoImage = data.flatMap(NSImage.init(data:))
        }
    }

    nonisolated private static func imageData(from url: URL) async -> Data? {
        await Task.detached(priority: .utility) {
            try? Data(contentsOf: url)
        }.value
    }

    private func programItemSupportsSeeking(_ item: ProgramItem) -> Bool {
        item.sourceKind.supportsSeeking
    }

    var projectionService: ProjectionService {
        ProjectionService(
            externalScreenProvider: externalScreenProvider,
            hasExternalDisplaySnapshot: isExternalDisplayAvailable
        )
    }

    var hasExternalDisplay: Bool {
        isExternalDisplayAvailable
    }

    func refreshExternalDisplayAvailability() {
        isExternalDisplayAvailable = externalScreenProvider() != nil
    }

    private func setupExternalDisplayObserver() {
        refreshExternalDisplayAvailability()
        externalDisplayChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshExternalDisplayAvailability()
            }
        }
    }

    // MARK: - 持久化

    func saveData() {
        let persistentProgramItems = ProgramQueueStore.persistentProgramItems(from: programItems)
        let pushPaths = persistentProgramItems.map { $0.sourceURL?.path ?? "" }
        let pushSubtitles = persistentProgramItems.map { $0.subtitle }
        let pushTitles = persistentProgramItems.map { $0.title }
        let pushScheduledStarts = ProgramQueueStore.encodedScheduleStarts(for: persistentProgramItems)
        let pushScheduledDurations = ProgramQueueStore.encodedScheduleDurations(for: persistentProgramItems)
        userDefaults.set(pushPaths, forKey: UDKeys.pushList)
        userDefaults.set(pushTitles, forKey: "pushList_titles")
        userDefaults.set(pushSubtitles, forKey: "pushList_subtitles")
        userDefaults.set(pushScheduledStarts, forKey: UDKeys.pushListScheduledStarts)
        userDefaults.set(pushScheduledDurations, forKey: UDKeys.pushListScheduledDurations)

        let bgmPaths = bgmItems.map { $0.url.path }
        let bgmCategories = bgmItems.map { $0.category.rawValue }
        let bgmTitles = bgmItems.map { $0.title }
        userDefaults.set(bgmPaths, forKey: UDKeys.bgmList)
        userDefaults.set(bgmCategories, forKey: UDKeys.bgmListCategories)
        userDefaults.set(bgmTitles, forKey: "bgmList_titles")

        let wallpaperPaths = backgroundWallpapers.map { $0.path }
        userDefaults.set(wallpaperPaths, forKey: UDKeys.wallpapers)
        if let activeWallpaperURL {
            userDefaults.set(activeWallpaperURL.path, forKey: UDKeys.activeWallpaper)
        } else {
            userDefaults.removeObject(forKey: UDKeys.activeWallpaper)
        }
        if let cornerLogoURL {
            userDefaults.set(cornerLogoURL.path, forKey: UDKeys.cornerLogo)
        } else {
            userDefaults.removeObject(forKey: UDKeys.cornerLogo)
        }
        userDefaults.set(cornerLogoPosition.rawValue, forKey: UDKeys.cornerLogoPosition)

        if let lowerThirdPresetData = try? JSONEncoder().encode(lowerThirdPresets) {
            userDefaults.set(lowerThirdPresetData, forKey: UDKeys.lowerThirdPresets)
        }

        if let countdownPresetData = try? JSONEncoder().encode(countdownPresets) {
            userDefaults.set(countdownPresetData, forKey: UDKeys.countdownPresets)
        }

        if let tickerPresetData = try? JSONEncoder().encode(tickerPresets) {
            userDefaults.set(tickerPresetData, forKey: UDKeys.tickerPresets)
        }
    }

    func loadData() {
        // Fix Issue #2: loadData is called from @MainActor init, all @Published updates are safe
        if let paths = userDefaults.stringArray(forKey: UDKeys.pushList) {
            let titles = userDefaults.stringArray(forKey: "pushList_titles") ?? []
            let subtitles = userDefaults.stringArray(forKey: "pushList_subtitles") ?? []
            let scheduledStarts = userDefaults.stringArray(forKey: UDKeys.pushListScheduledStarts) ?? []
            let scheduledDurations = userDefaults.stringArray(forKey: UDKeys.pushListScheduledDurations) ?? []
            let missingCount = paths.enumerated().filter { index, path in
                if path.isEmpty,
                   index < subtitles.count,
                   ProgramItem.isAgendaMarkerSubtitle(subtitles[index]) {
                    return false
                }
                return !FileManager.default.fileExists(atPath: path)
            }.count
            if missingCount > 0 {
                recordSupportEvent(kind: .programItemFileMissing, detail: "count=\(missingCount)")
            }
            programItems.append(
                contentsOf: ProgramQueueStore.restoredProgramItems(
                    paths: paths,
                    titles: titles,
                    subtitles: subtitles,
                    scheduledStarts: scheduledStarts,
                    scheduledDurations: scheduledDurations
                )
            )
        }

        if let paths = userDefaults.stringArray(forKey: UDKeys.bgmList) {
            let categories = userDefaults.stringArray(forKey: UDKeys.bgmListCategories) ?? []
            let titles = userDefaults.stringArray(forKey: "bgmList_titles") ?? []
            var missingCount = 0
            for (i, path) in paths.enumerated() {
                let url = URL(fileURLWithPath: path)
                guard FileManager.default.fileExists(atPath: path) else {
                    missingCount += 1
                    continue
                }
                let catRaw = i < categories.count ? categories[i] : BGMCategory.warmUp.rawValue
                let cat = BGMCategory(rawValue: catRaw) ?? .warmUp
                let title = i < titles.count ? titles[i] : url.deletingPathExtension().lastPathComponent
                let item = BGMItem(title: title, url: url, category: cat)
                bgmItems.append(item)
            }
            if missingCount > 0 {
                recordSupportEvent(kind: .bgmFileMissing, detail: "count=\(missingCount)")
            }
        }

        if let paths = userDefaults.stringArray(forKey: UDKeys.wallpapers) {
            let missingCount = paths.filter { !FileManager.default.fileExists(atPath: $0) }.count
            if missingCount > 0 {
                recordSupportEvent(kind: .wallpaperFileMissing, detail: "count=\(missingCount)")
            }
            backgroundWallpapers = paths.compactMap { path -> URL? in
                let url = URL(fileURLWithPath: path)
                return FileManager.default.fileExists(atPath: path) ? url : nil
            }
            // Bug1修复：loadData后恢复activeWallpaperURL，确保暂停/空闲时大屏显示壁纸而非黑屏
            if activeWallpaperURL == nil {
                if let activePath = userDefaults.string(forKey: UDKeys.activeWallpaper) {
                    let activeURL = URL(fileURLWithPath: activePath)
                    activeWallpaperURL = backgroundWallpapers.contains(activeURL) ? activeURL : backgroundWallpapers.first
                } else {
                    activeWallpaperURL = backgroundWallpapers.first
                }
            }
        }

        if let rawPosition = userDefaults.string(forKey: UDKeys.cornerLogoPosition),
           let position = CornerLogoPosition(rawValue: rawPosition) {
            cornerLogoPosition = position
        }
        if let logoPath = userDefaults.string(forKey: UDKeys.cornerLogo) {
            let logoURL = URL(fileURLWithPath: logoPath)
            cornerLogoURL = WallpaperImagePolicy.isSupported(url: logoURL) ? logoURL : nil
        }

        if let storedAudioStrategy = userDefaults.string(forKey: UDKeys.audioStrategy),
           let audioStrategy = AudioStrategy(persistedValue: storedAudioStrategy) {
            self.audioStrategy = audioStrategy
        }

        if userDefaults.object(forKey: UDKeys.speakerMode) != nil {
            isSpeakerMode = userDefaults.bool(forKey: UDKeys.speakerMode)
        }

        if userDefaults.object(forKey: UDKeys.autoPlayNextVideoOnEnd) != nil {
            autoPlayNextVideoOnEnd = userDefaults.bool(forKey: UDKeys.autoPlayNextVideoOnEnd)
        }

        if userDefaults.object(forKey: UDKeys.autoAdvanceAtScheduledTime) != nil {
            autoAdvanceAtScheduledTime = userDefaults.bool(forKey: UDKeys.autoAdvanceAtScheduledTime)
        }

        if userDefaults.object(forKey: UDKeys.showAgendaTimeline) != nil {
            showAgendaTimeline = userDefaults.bool(forKey: UDKeys.showAgendaTimeline)
        }

        if let rawConsoleMode = userDefaults.string(forKey: UDKeys.consoleMode),
           let storedConsoleMode = ConsoleMode(rawValue: rawConsoleMode) {
            consoleMode = storedConsoleMode
        }

        if let rawTheme = userDefaults.string(forKey: UDKeys.themeOverride),
           let storedTheme = ThemeOverride(rawValue: rawTheme) {
            themeOverride = storedTheme
        }

        if let lowerThirdPresetData = userDefaults.data(forKey: UDKeys.lowerThirdPresets),
           let storedPresets = try? JSONDecoder().decode([LowerThirdPreset].self, from: lowerThirdPresetData) {
            lowerThirdPresets = LowerThirdPreset.normalized(storedPresets)
        }

        if let countdownPresetData = userDefaults.data(forKey: UDKeys.countdownPresets),
           let storedPresets = try? JSONDecoder().decode([CountdownPreset].self, from: countdownPresetData) {
            countdownPresets = CountdownPreset.normalized(storedPresets)
        }

        if let tickerPresetData = userDefaults.data(forKey: UDKeys.tickerPresets),
           let storedPresets = try? JSONDecoder().decode([TickerPreset].self, from: tickerPresetData) {
            tickerPresets = TickerPreset.normalized(storedPresets)
        }
    }

    // MARK: - 播毕回调绑定

    private func setupPlayerCoordinator() {
        avCoordinator.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyAudioRoutingForRuntimeChange(reason: .mediaPlaybackChanged)
            }
            .store(in: &cancellables)

        avCoordinator.onPlaybackEnded = { [weak self] in
            self?.handlePlaybackEnded()
        }
    }

    // MARK: - 节目操作

    func switchToProgram(_ item: ProgramItem) {
        switch item.sourceKind {
        case .agendaMarker, .unsupported:
            return
        case .media:
            guard let url = item.sourceURL else { return }
            currentHTMLURL = nil              // 清空 HTML 层
            avCoordinator.load(url: url)
            if isPanicMode {
                avCoordinator.pause()
            } else {
                avCoordinator.play()
            }
            currentProgramItem = item
        case .keynote:
            guard let url = item.sourceURL else { return }
            if !isLikelyValidDeckDocument(url: url) {
                invalidDeckHandler(url)
                return
            }
            currentProgramItem = item
            currentHTMLURL = nil              // 清空 HTML 层
            avCoordinator.stop()              // 清空旧视频，避免副屏/监视器残留上一条节目
            keynotePresentationHandler(url)
        case .pptx:
            guard let url = item.sourceURL else { return }
            currentProgramItem = item
            currentHTMLURL = nil              // 清空 HTML 层
            avCoordinator.stop()              // 清空旧视频，避免副屏/监视器残留上一条节目
            pptxOpenHandler(url)
        case .html:
            guard let url = item.sourceURL else { return }
            currentProgramItem = item
            avCoordinator.stop()              // Bug3修复：stop清空currentURL，监视器不再显示视频
            openHTMLInOutputWindow(url: url)
        case .activeDeck:
            currentProgramItem = item
            currentHTMLURL = nil
            avCoordinator.stop()
            activeDeckPresentationHandler()
        }
    }

    func switchToProgramAfterReadinessConfirmation(_ item: ProgramItem) {
        let readiness = PresentationReadinessProbe.probe(item: item)
        guard readiness.severity == .blocked else {
            switchToProgram(item)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Presentation is not ready"
        alert.informativeText = "\(readiness.operatorMessage)\n\nContinue anyway?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        switchToProgram(item)
    }

    private func isLikelyValidDeckDocument(url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .fileSizeKey]
        let values = try? url.resourceValues(forKeys: keys)

        if values?.isDirectory == true || values?.isPackage == true {
            return true
        }

        if let fileSize = values?.fileSize {
            return fileSize > 0
        }

        return false
    }

    private func presentInvalidDeckAlert(for url: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "当前 Keynote 文件无效"
        alert.informativeText = "“\(url.lastPathComponent)” 不是可直接播放的 Keynote 文稿，已阻止发送给 Keynote。请删除这条节目，或重新导入真实的 .key 文件。"
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    private func runAutomationScript(
        _ source: String,
        action: String,
        alertTitle: String? = nil,
        alertMessage: String? = nil
    ) {
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try AppleScriptRunner.run(source, action: action)
            } catch {
                await self?.handleAppleScriptFailure(
                    error,
                    action: action,
                    alertTitle: alertTitle,
                    alertMessage: alertMessage
                )
            }
        }
    }

    func handleAppleScriptFailure(
        _ error: Error,
        action: String,
        alertTitle: String? = nil,
        alertMessage: String? = nil
    ) {
        let message = appleScriptFailureMessage(error)
        recordSupportEvent(kind: .appleScriptFailed, detail: "action=\(action),error=\(message)")

        if let alertTitle {
            automationFailureAlertHandler(alertTitle, alertMessage ?? message)
        }
    }

    private func appleScriptFailureMessage(_ error: Error) -> String {
        if let error = error as? AppleScriptError {
            return error.message
        }
        if let description = (error as? LocalizedError)?.errorDescription, !description.isEmpty {
            return description
        }
        return String(describing: error)
    }

    nonisolated private static func openWithWPSOffice(url: URL) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "WPS Office", url.path]
        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw AppleScriptError.executionFailed(
                action: "wps.open.command",
                message: "open exited with status \(task.terminationStatus)"
            )
        }
    }

    /// 将 HTML 文件推送到副屏 WKWebView
    func openHTMLInOutputWindow(url: URL) {
        currentHTMLURL = url
        // isBroadcasting 时 objectWillChange 已由 @Published 自动触发，无需手动 send
    }

    /// 结束 HTML 展示，回到空闲壁纸态。
    func endHTMLPresentation() {
        currentHTMLURL = nil
        currentProgramItem = nil
    }

    /// 当前节目播毕后的最小状态回退。
    func handlePlaybackEnded() {
        LiveSwitcherTelemetry.playbackReachedEnd()
        recordSupportEvent(kind: .playbackReachedEnd, detail: "state=ended")

        guard !isPanicMode else {
            avCoordinator.pause()
            return
        }

        if autoPlayNextVideoIfPossible() {
            return
        }

        withAnimation(.easeInOut(duration: 0.5)) {
            currentHTMLURL = nil
            currentProgramItem = nil
        }
    }

    private func autoPlayNextVideoIfPossible() -> Bool {
        guard autoPlayNextVideoOnEnd,
              let nextItem = ProgramQueueStore.nextVideoAfterCurrent(
                current: currentProgramItem,
                in: programItems
              ) else { return false }
        switchToProgram(nextItem)
        return true
    }

    /// Fix Issue #3: 打开并立即放映 Keynote 文件
    func openAndPresentKeynote(url: URL) {
        let script = PresentationAutomationService.keynoteStartScript(url: url)
        runAutomationScript(
            script,
            action: "keynote.open.present",
            alertTitle: "Keynote 自动化失败",
            alertMessage: "Keynote 无法打开或放映当前文稿。请确认 Keynote 已安装，并允许 LiveSwitcher 控制 Keynote。"
        )
    }

    /// V24 Fix #3: PPTX → 默认调取 WPS Office 执行播放（彻底替换 Keynote 调用逻辑）
    func openPPTXWithKeynote(url: URL) {
        Task.detached(priority: .userInitiated) { [weak self] in
            // 优先尝试 WPS Office
            let wpsScript = PresentationAutomationService.wpsOpenScript(url: url)
            do {
                try AppleScriptRunner.run(wpsScript, action: "wps.open.script")
                return
            } catch {
                await self?.handleAppleScriptFailure(error, action: "wps.open.script")
            }

            // WPS AppleScript 不可用时，降级用 open -a 命令行方式打开 WPS
            do {
                try Self.openWithWPSOffice(url: url)
            } catch {
                await self?.handleAppleScriptFailure(
                    error,
                    action: "wps.open.command",
                    alertTitle: "未检测到 WPS Office / Keynote",
                    alertMessage: "LiveSwitcher 无法通过 WPS Office 打开当前 PPTX。请确认 WPS Office 已安装，或改用可直接放映的 Keynote 文件。"
                )
            }
        }
    }

    /// 放映当前最前面的 Keynote 文档
    func presentFrontKeynoteDocument() {
        let script = """
        tell application "Keynote"
            if (count of documents) > 0 then
                start (front document) from (slide 1 of front document)
            end if
        end tell
        """
        runAutomationScript(
            script,
            action: "keynote.present.front",
            alertTitle: "Keynote 自动化失败",
            alertMessage: "LiveSwitcher 无法放映当前最前面的 Keynote 文稿。请确认 Keynote 已打开文稿并完成自动化授权。"
        )
    }

    /// Fix Issue #4: Keynote 下一张（右箭头）
    func keynoteNextSlide() {
        let script = """
        tell application "Keynote"
            if playing is true then
                show next
            end if
        end tell
        """
        runAutomationScript(
            script,
            action: "keynote.next-slide",
            alertTitle: "Keynote 翻页失败",
            alertMessage: "LiveSwitcher 未能切到下一页。请确认 Keynote 正在放映，并允许 LiveSwitcher 控制 Keynote。"
        )
    }

    /// Fix Issue #4: Keynote 上一张（左箭头）
    func keynotePreviousSlide() {
        let script = """
        tell application "Keynote"
            if playing is true then
                show previous
            end if
        end tell
        """
        runAutomationScript(
            script,
            action: "keynote.previous-slide",
            alertTitle: "Keynote 翻页失败",
            alertMessage: "LiveSwitcher 未能切到上一页。请确认 Keynote 正在放映，并允许 LiveSwitcher 控制 Keynote。"
        )
    }

    func scanAndAddKeynoteWindows() {
        let script = """
        tell application "System Events"
            try
                get name of every window of application process "Keynote"
            on error
                return {}
            end try
        end tell
        """
        let result: NSAppleEventDescriptor
        do {
            result = try AppleScriptRunner.run(script, action: "keynote.scan.windows")
        } catch {
            handleAppleScriptFailure(error, action: "keynote.scan.windows")
            return
        }

        var windowNames: [String] = []
        if result.numberOfItems > 0 {
            for i in 1...result.numberOfItems {
                if let item = result.atIndex(i), let name = item.stringValue {
                    windowNames.append(name)
                }
            }
        } else if let single = result.stringValue, !single.isEmpty {
            windowNames.append(single)
        }

        let docPaths = keynoteController.scanOpenKeynoteFiles()

        if !docPaths.isEmpty {
            for path in docPaths {
                let url = URL(fileURLWithPath: path)
                let alreadyAdded = programItems.contains { $0.sourceURL == url }
                if !alreadyAdded {
                    let item = ProgramItem(
                        title: url.deletingPathExtension().lastPathComponent,
                        subtitle: "KEY",
                        sourceURL: url
                    )
                    addProgramItem(item)
                }
            }
        } else if !windowNames.isEmpty {
            for name in windowNames {
                let cleanName = name.replacingOccurrences(of: ".key", with: "")
                    .replacingOccurrences(of: ".pptx", with: "")
                let alreadyAdded = programItems.contains { $0.title == cleanName }
                if !alreadyAdded {
                    let item = ProgramItem(
                        title: cleanName,
                        subtitle: "KEY (活动)",
                        sourceURL: nil
                    )
                    addProgramItem(item)
                }
            }
        }
        saveData()
    }

    func switchToProgram(at index: Int) {
        guard index >= 0 && index < programItems.count else { return }
        switchToProgram(programItems[index])
    }

    /// Fix Issue #4: 空格键 - 暂停/继续（也处理 Keynote 播放状态）
    func toggleMainVideoPlayback() {
        guard let item = currentProgramItem else { return }

        switch item.sourceKind {
        case .activeDeck, .keynote, .pptx:
            deckStopHandler()
            return
        case .html, .agendaMarker, .unsupported:
            return
        case .media:
            break
        }

        guard !isPanicMode else {
            if avCoordinator.isPlaying {
                avCoordinator.pause()
                applyAudioRoutingForRuntimeChange(reason: .mediaPlaybackChanged)
            }
            return
        }

        // 普通视频
        if avCoordinator.isPlaying {
            avCoordinator.pause()
            applyAudioRoutingForRuntimeChange(reason: .mediaPlaybackChanged)
        } else {
            avCoordinator.play()
            applyAudioRoutingForRuntimeChange(reason: .mediaPlaybackChanged)
        }
    }

    private func stopDeckPresentation() {
        let script = """
        tell application "Keynote"
            if playing is true then
                stop the front document
            end if
        end tell
        """
        runAutomationScript(
            script,
            action: "keynote.stop.presentation",
            alertTitle: "Keynote 停止失败",
            alertMessage: "LiveSwitcher 未能停止当前 Keynote 放映。请确认 Keynote 仍在运行并完成自动化授权。"
        )
    }

    func togglePause(for item: ProgramItem) {
        guard currentProgramItem?.id == item.id else {
            switchToProgram(item)
            return
        }
        toggleMainVideoPlayback()
    }

    func seekProgramItemToStart(_ item: ProgramItem) {
        if currentProgramItem?.id == item.id && programItemSupportsSeeking(item) {
            programSeekToStartHandler()
        }
    }

    func restartCurrentMediaFromBeginning() {
        guard let item = currentProgramItem,
              programItemSupportsSeeking(item) else { return }
        programSeekToStartHandler()
        if !isPanicMode {
            avCoordinator.play()
        }
        applyAudioRoutingForRuntimeChange(reason: .mediaPlaybackChanged)
        recordSupportEvent(kind: .mediaRestarted, detail: "source=current")
    }

    func seekProgramItemToEnd(_ item: ProgramItem) {
        if currentProgramItem?.id == item.id && programItemSupportsSeeking(item) {
            programSeekToEndHandler()
        }
    }

    func addProgramItem(_ item: ProgramItem) {
        addProgramItems([item])
    }

    func addProgramItems(_ items: [ProgramItem]) {
        guard !items.isEmpty else { return }
        programItems.append(contentsOf: items)
        saveData()
    }

    func addAgendaMarker(title: String = "Break") {
        let start = programItems.last.flatMap { item -> Date? in
            guard let scheduledStartAt = item.scheduledStartAt,
                  let scheduledDuration = item.scheduledDuration else { return nil }
            return scheduledStartAt.addingTimeInterval(scheduledDuration)
        }
        addProgramItem(ProgramItem.agendaMarker(title: title, scheduledStartAt: start))
    }

    func updateProgramItemSchedule(
        id: UUID,
        scheduledStartAt: Date?,
        scheduledDuration: TimeInterval?
    ) {
        guard let index = programItems.firstIndex(where: { $0.id == id }) else { return }
        programItems[index].scheduledStartAt = scheduledStartAt
        programItems[index].scheduledDuration = scheduledDuration
        if currentProgramItem?.id == id {
            currentProgramItem = programItems[index]
        }
        agendaAutoAdvancePromptedItemIDs.remove(id)
        saveData()
    }

    func removeProgramItem(withID id: UUID) {
        programItems.removeAll { $0.id == id }
        if currentProgramItem?.id == id {
            currentProgramItem = nil
            currentHTMLURL = nil   // Bug2修复：删除HTML条目时清空大屏
            avCoordinator.stop()
        }
        saveData()
    }

    func moveProgramItems(from source: IndexSet, to destination: Int) {
        programItems.move(fromOffsets: source, toOffset: destination)
        saveData()
    }

    func agendaAutoAdvancePrompt(now: Date = Date()) -> AgendaAutoAdvancePrompt? {
        AgendaAutoAdvanceModel.prompt(
            isEnabled: autoAdvanceAtScheduledTime,
            programItems: programItems,
            currentProgramItem: currentProgramItem,
            now: now,
            promptedItemIDs: agendaAutoAdvancePromptedItemIDs
        )
    }

    func dismissAgendaAutoAdvancePrompt(_ prompt: AgendaAutoAdvancePrompt) {
        agendaAutoAdvancePromptedItemIDs.insert(prompt.itemID)
    }

    func confirmAgendaAutoAdvance(_ prompt: AgendaAutoAdvancePrompt) {
        agendaAutoAdvancePromptedItemIDs.insert(prompt.itemID)
        guard let item = programItems.first(where: { $0.id == prompt.itemID }) else { return }
        switchToProgramAfterReadinessConfirmation(item)
    }

    // MARK: - 壁纸库操作

    @discardableResult
    func addWallpaper(url: URL) -> Bool {
        guard isSupportedWallpaperImage(url) else { return false }
        guard !backgroundWallpapers.contains(url) else { return true }
        backgroundWallpapers.append(url)
        saveData()
        return true
    }

    func removeWallpaper(url: URL) {
        backgroundWallpapers.removeAll { $0 == url }
        if activeWallpaperURL == url {
            activeWallpaperURL = backgroundWallpapers.first
        }
        saveData()
    }

    func setActiveWallpaper(url: URL) {
        guard backgroundWallpapers.contains(url) else { return }
        activeWallpaperURL = url
        saveData()
    }

    @discardableResult
    func setCornerLogo(url: URL) -> Bool {
        guard WallpaperImagePolicy.isSupported(url: url) else { return false }
        cornerLogoURL = url
        saveData()
        return true
    }

    func removeCornerLogo() {
        cornerLogoURL = nil
        saveData()
    }

    private func isSupportedWallpaperImage(_ url: URL) -> Bool {
        WallpaperImagePolicy.isSupported(url: url)
    }

    // MARK: - BGM 操作

    @discardableResult
    func addBGMItem(_ item: BGMItem) -> Bool {
        addBGMItems([item]) == 1
    }

    @discardableResult
    func addBGMItems(_ items: [BGMItem]) -> Int {
        guard !items.isEmpty else { return 0 }
        var importedCount = 0
        for item in items {
            guard BGMDuplicatePolicy.decision(for: item.url, existingItems: bgmItems) != .duplicateURL else {
                recordSupportEvent(kind: .bgmImportSkippedDuplicate, detail: "reason=duplicateURL")
                continue
            }
            bgmItems.append(item)
            importedCount += 1
        }
        if importedCount > 0 {
            saveData()
        }
        return importedCount
    }

    func removeBGMItem(_ item: BGMItem) {
        bgmItems.removeAll { $0.id == item.id }
        if currentBGMItem?.id == item.id {
            bgmTransitionGeneration += 1
            let generation = bgmTransitionGeneration
            let fadeDur = liveAudioFadeDuration
            stopBGMTimer()
            clearBGMTakeoverIfNeeded()
            fadeMediaVolume(to: effectiveMediaOutputVolume(), duration: fadeDur)
            if let removedPlayer = bgmAudioPlayer {
                fadeBGMPlayerVolume(removedPlayer, to: 0, duration: fadeDur)
                releaseBGMPlayerAfterFade(removedPlayer, duration: fadeDur)
            }
            bgmAudioPlayer = nil
            fadeBGMFallbackVolume(to: 0, duration: fadeDur)
            releaseBGMFallbackAfterFade(duration: fadeDur, generation: generation)
            currentBGMItem = nil
            isBGMPlaying = false
            bgmProgress = 0
            bgmCurrentTime = 0
            bgmDuration = nil
            resetBGMRealtimeMeter()
            recordBGMPlaybackState(isPlaying: false, reason: "removed")
            applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
        }
        saveData()
    }

    func moveBGMItems(from source: IndexSet, to destination: Int) {
        bgmItems.move(fromOffsets: source, toOffset: destination)
        saveData()
    }

    func moveBGMItems(in category: BGMCategory, from source: IndexSet, to destination: Int) {
        let categoryOffsets = bgmItems.indices.filter { bgmItems[$0].category == category }
        guard !categoryOffsets.isEmpty else { return }

        var scopedItems = categoryOffsets.map { bgmItems[$0] }
        scopedItems.move(fromOffsets: source, toOffset: destination)

        for (scopedIndex, originalIndex) in categoryOffsets.enumerated() {
            bgmItems[originalIndex] = scopedItems[scopedIndex]
        }
        saveData()
    }

    func seekBGMToBeginning() {
        bgmAudioPlayer?.currentTime = 0
        bgmFallbackPlayer.seek(to: .zero)
        bgmProgressStore.update(currentTime: 0, duration: bgmAudioPlayer?.duration ?? bgmDuration ?? 0)
    }

    func seekBGM(toProgress progress: Double) {
        let clampedProgress = BGMProgressStore.clampedProgress(progress)
        guard let player = bgmAudioPlayer else {
            guard let duration = bgmDuration, duration > 0 else {
                bgmProgress = clampedProgress
                return
            }
            let targetTime = duration * clampedProgress
            bgmFallbackPlayer.seek(to: CMTime(seconds: targetTime, preferredTimescale: 600))
            bgmProgressStore.update(currentTime: targetTime, duration: duration)
            return
        }
        let duration = player.duration
        guard duration > 0 else {
            bgmProgressStore.update(currentTime: 0, duration: 0)
            return
        }
        player.currentTime = duration * clampedProgress
        bgmProgressStore.update(currentTime: player.currentTime, duration: duration)
    }

    func toggleBGM(_ item: BGMItem) {
        guard !isPanicMode else {
            cueBGMDuringPanic(item)
            return
        }

        if currentBGMItem?.id == item.id {
            if isBGMPlaying {
                // BGM 停止时只解除临时接管，不改变用户选择的混音策略。
                bgmTransitionGeneration += 1
                let generation = bgmTransitionGeneration
                let fadeDur = liveAudioFadeDuration
                isBGMPlaying = false
                resetBGMRealtimeMeter()
                clearBGMTakeoverIfNeeded()
                recordBGMPlaybackState(isPlaying: false, reason: "operator")
                let capturedPlayer = bgmAudioPlayer
                let stoppingItemID = item.id
                let pauseDelay = BGMFadeCompletionPolicy.pauseDelay(fadeDuration: fadeDur)
                applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
                Task { @MainActor [weak self, weak capturedPlayer] in
                    if pauseDelay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(pauseDelay * 1_000_000_000))
                    }
                    guard let self,
                          self.bgmTransitionGeneration == generation,
                          self.currentBGMItem?.id == stoppingItemID,
                          !self.isBGMPlaying else { return }
                    capturedPlayer?.pause()
                }
                Task { @MainActor [weak self] in
                    if pauseDelay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(pauseDelay * 1_000_000_000))
                    }
                    guard let self else { return }
                    if self.bgmTransitionGeneration == generation,
                       self.currentBGMItem?.id == stoppingItemID,
                       !self.isBGMPlaying {
                        self.bgmFallbackPlayer.pause()
                    }
                }
                stopBGMTimer()
                if fadeDur <= 0 {
                    bgmAudioPlayer?.volume = 0
                    bgmFallbackPlayer.volume = 0
                }
            } else {
                // BGM 恢复播放只启动音乐通道；实际路由继续由用户选择的 audioStrategy 决定。
                bgmTransitionGeneration += 1
                isBGMPlaying = true
                bgmAudioPlayer?.volume = 0
                bgmAudioPlayer?.isMeteringEnabled = true
                bgmAudioPlayer?.play()
                bgmFallbackPlayer.volume = 0
                bgmFallbackPlayer.play()
                applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
                startBGMTimer()
                recordBGMPlaybackState(isPlaying: true, reason: "operator")
            }
        } else {
            stopBGMTimer()
            bgmTransitionGeneration += 1
            let fadeDur = liveAudioFadeDuration

            // 切歌时取消旧 fallback fade，避免旧任务回写新曲目的目标音量。
            bgmPlayerVolumeFadeTask?.cancel()
            bgmFallbackVolumeFadeTask?.cancel()
            if let oldPlayer = bgmAudioPlayer {
                fadeBGMPlayerVolume(oldPlayer, to: 0, duration: fadeDur)
                releaseBGMPlayerAfterFade(oldPlayer, duration: fadeDur)
            }
            bgmAudioPlayer?.delegate = nil
            bgmAudioPlayer = nil
            resetBGMRealtimeMeter()
            removeBGMFallbackEndObserver()
            bgmFallbackPlayer.pause()
            bgmFallbackPlayer.replaceCurrentItem(with: nil)

            currentBGMItem = item
            isBGMPlaying = true
            let targetVolume = effectiveBGMOutputVolume()

            if let player = try? AVAudioPlayer(contentsOf: item.url) {
                player.volume = 0  // Bug Fix #1: 从0开始，淡入至目标音量
                player.numberOfLoops = BGMPlaybackEndPolicy.numberOfLoops(for: bgmPlayMode)
                player.delegate = bgmDelegate  // V21 Fix #1: 播完回调
                player.isMeteringEnabled = true
                player.prepareToPlay()
                player.play()
                bgmAudioPlayer = player
                fadeBGMPlayerVolume(to: targetVolume, duration: fadeDur)
                bgmDuration = player.duration > 0 ? player.duration : nil
            } else {
                let avItem = AVPlayerItem(url: item.url)
                installBGMFallbackEndObserver(for: avItem)
                bgmFallbackPlayer.replaceCurrentItem(with: avItem)
                bgmFallbackPlayer.volume = 0
                bgmFallbackPlayer.play()
                bgmDuration = nil
                resetBGMRealtimeMeter()
            }
            bgmProgress = 0
            bgmCurrentTime = 0
            applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
            startBGMTimer()
            recordBGMPlaybackState(isPlaying: true, reason: "selected")
        }
    }

    private func cueBGMDuringPanic(_ item: BGMItem) {
        stopBGMTimer()
        resetBGMRealtimeMeter()
        clearBGMTakeoverIfNeeded()
        bgmTransitionGeneration += 1
        bgmAudioPlayer?.delegate = nil
        bgmAudioPlayer = nil
        bgmPlayerVolumeFadeTask?.cancel()
        bgmFallbackVolumeFadeTask?.cancel()
        removeBGMFallbackEndObserver()
        bgmFallbackPlayer.volume = 0
        bgmFallbackPlayer.pause()
        bgmFallbackPlayer.replaceCurrentItem(with: nil)
        currentBGMItem = item
        isBGMPlaying = false
        bgmProgress = 0
        bgmCurrentTime = 0
        bgmDuration = nil
        applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
        recordBGMPlaybackState(isPlaying: false, reason: "cuedDuringPanic")
    }

    func clearBGMTakeoverIfNeeded() {
        guard isBGMAudioTakeoverActive else { return }
        isBGMAudioTakeoverActive = false
        LiveSwitcherTelemetry.bgmTakeoverChanged(isActive: false)
        recordSupportEvent(kind: .bgmTakeoverChanged, detail: "isActive=false")
    }

    func recordBGMPlaybackState(isPlaying: Bool, reason: String) {
        recordSupportEvent(kind: .bgmPlaybackChanged, detail: "isPlaying=\(isPlaying),reason=\(reason)")
    }

    // MARK: - BGM Progress Timer

    func startBGMTimer() {
        stopBGMTimer()
        bgmProgressTimer = Timer.scheduledTimer(withTimeInterval: BGMProgressStore.updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateBGMProgress()
            }
        }
    }

    func stopBGMTimer() {
        bgmProgressTimer?.invalidate()
        bgmProgressTimer = nil
    }

    private func releaseBGMPlayerAfterFade(_ player: AVAudioPlayer, duration: Double) {
        let taskID = UUID()
        bgmTransitionTasks[taskID] = Task { @MainActor [weak self] in
            defer { self?.bgmTransitionTasks[taskID] = nil }
            if duration > 0 {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            player.delegate = nil
            player.stop()
        }
    }

    private func releaseBGMFallbackAfterFade(duration: Double, generation: Int) {
        let taskID = UUID()
        bgmTransitionTasks[taskID] = Task { @MainActor [weak self] in
            defer { self?.bgmTransitionTasks[taskID] = nil }
            if duration > 0 {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            }
            guard let self, !Task.isCancelled, self.bgmTransitionGeneration == generation else { return }
            guard self.currentBGMItem == nil, !self.isBGMPlaying else { return }
            self.bgmFallbackPlayer.volume = 0
            self.bgmFallbackPlayer.pause()
            self.removeBGMFallbackEndObserver()
            self.bgmFallbackPlayer.replaceCurrentItem(with: nil)
        }
    }

    func cancelBGMFallbackFade() {
        bgmFallbackVolumeFadeTask?.cancel()
        bgmFallbackVolumeFadeTask = nil
    }

    private func updateBGMProgress() {
        if let player = bgmAudioPlayer {
            let currentTime = player.currentTime
            let duration = player.duration
            bgmProgressStore.update(currentTime: currentTime, duration: duration)
            updateBGMRealtimeMeter(from: player)
            finishBGMIfProgressReachedEnd(currentTime: currentTime, duration: duration)
        } else if isBGMPlaying {
            let fallbackTime = bgmFallbackPlayer.currentTime().seconds
            let itemDuration = bgmFallbackPlayer.currentItem?.duration.seconds
            let fallbackDuration = bgmDuration ?? ((itemDuration ?? 0) > 0 && itemDuration?.isFinite == true ? itemDuration : nil)
            if fallbackTime.isFinite, let fallbackDuration, fallbackDuration > 0 {
                bgmProgressStore.update(currentTime: fallbackTime, duration: fallbackDuration)
                finishBGMIfProgressReachedEnd(currentTime: fallbackTime, duration: fallbackDuration)
            }
            resetBGMRealtimeMeter()
        } else {
            resetBGMRealtimeMeter()
        }
    }

    private func finishBGMIfProgressReachedEnd(currentTime: Double, duration: Double?) {
        guard BGMPlaybackEndPolicy.shouldTreatAsFinished(
            isPlaying: isBGMPlaying,
            playMode: bgmPlayMode,
            currentTime: currentTime,
            duration: duration
        ) else { return }
        bgmAudioPlayer?.delegate = nil
        bgmDidFinish()
    }

    func resetBGMRealtimeMeter() {
        bgmRealtimeLevelDB = nil
    }

    private func updateBGMRealtimeMeter(from player: AVAudioPlayer) {
        guard player.isMeteringEnabled, player.numberOfChannels > 0 else {
            resetBGMRealtimeMeter()
            return
        }

        player.updateMeters()
        bgmRealtimeLevelDB = player.averagePower(forChannel: 0)
    }

    // MARK: - 推流控制

    func handleBroadcastToggle() {
        if !isBroadcasting, !projectionService.hasExternalDisplay {
            broadcastSafetyNotice = "未检测到外接屏幕，未开始投射"
            LiveSwitcherTelemetry.projectionFailClosed()
            recordSupportEvent(kind: .projectionFailClosed, detail: "externalDisplay=false")
            recordSupportEvent(kind: .projectionStartFailed, detail: "externalDisplay=false")
            return
        }

        isBroadcasting.toggle()
        if isBroadcasting {
            showOutputWindow()
            recordSupportEvent(kind: .projectionStarted, detail: "isBroadcasting=true")
        } else {
            hideOutputWindow()
            recordSupportEvent(kind: .projectionStopped, detail: "isBroadcasting=false")
        }
        LiveSwitcherTelemetry.projectionToggle(isBroadcasting: isBroadcasting)
        recordSupportEvent(kind: .projectionToggle, detail: "isBroadcasting=\(isBroadcasting)")
    }

    func showOutputWindow() {
        guard let targetScreen = projectionService.targetScreen() else {
            handleExternalDisplayLost()
            return
        }

        if outputWindowController == nil {
            outputWindowController = outputWindowControllerFactory()
            outputWindowController?.onExternalDisplayUnavailable = { [weak self] in
                self?.handleExternalDisplayLost()
            }
            let outputView = AnyView(
                OutputView()
                    .environmentObject(self)
            )
            outputWindowController?.mountAnyView(rootView: outputView)
        }
        broadcastSafetyNotice = nil
        outputWindowController?.show(on: targetScreen, fullScreen: true)
    }

    func hideOutputWindow() {
        outputWindowController?.hide()
    }

    func handleExternalDisplayLost() {
        isBroadcasting = false
        outputWindowController?.hide()
        broadcastSafetyNotice = "副屏已断开，投射已停止"
        LiveSwitcherTelemetry.projectionFailClosed()
        recordSupportEvent(kind: .projectionFailClosed, detail: "externalDisplay=false")
        recordSupportEvent(kind: .projectionLost, detail: "externalDisplay=false")
    }

    func recordSupportEvent(
        kind: LiveSupportEventKind,
        detail: String,
        timestamp: Date = Date()
    ) {
        supportEvents.append(
            LiveSupportEvent(
                timestamp: timestamp,
                kind: kind,
                detail: detail
            )
        )
        if supportEvents.count > supportEventLimit {
            supportEvents.removeFirst(supportEvents.count - supportEventLimit)
        }
    }

    // MARK: - System Volume Observer

    private func setupSystemVolumeObserver() {
        guard systemVolumeObserver == nil else { return }
        let observer = SystemVolumeObserver { [weak self] volume, deviceID in
            guard let self else { return }
            // 只在差值 > 1% 时更新，防止循环触发
            if abs(volume - self.masterVolume) > 0.01 {
                self.masterVolume = volume
                LiveSwitcherTelemetry.systemVolumeSynced(volume: volume, deviceID: deviceID)
                self.recordSupportEvent(
                    kind: .systemVolumeSynced,
                    detail: "deviceID=\(deviceID),volume=\(String(format: "%.3f", volume))"
                )
            }
        }
        systemVolumeObserver = observer
        observer.start()
    }

    // MARK: - V25: 翻页拦截器控制

    /// 开关翻页拦截（isPageInterceptEnabled didSet 驱动）
    private func applyPageInterceptState() {
        if isPageInterceptEnabled {
            startPageIntercept()
        } else {
            stopPageIntercept()
        }
    }

    private func startPageIntercept() {
        // 权限预检查：无辅助功能权限时提前提示，避免 tapCreate 静默失败
        let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        if !AXIsProcessTrustedWithOptions(axOptions) {
            Task { @MainActor [weak self] in
                self?.isPageInterceptEnabled = false
                self?.recordSupportEvent(
                    kind: .pageInterceptDisabled,
                    detail: "reason=accessibilityPermission"
                )
                let alert = NSAlert()
                alert.messageText = "PPT模式需要辅助功能权限"
                alert.informativeText = "翻页笔接管需要「辅助功能」权限才能工作。\n\n请前往：系统设置 → 隐私与安全性 → 辅助功能，找到\"LiveSwitcher\"并打开开关。\n\n设置完成后，重新启动 App 即可使用 PPT模式。"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "稍后处理")
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            return
        }

        guard pageInterceptEventTap == nil else {
            // 已有 tap，直接 enable
            if let tap = pageInterceptEventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                pageInterceptRuntime.updateEventTap(tap)
                LiveSwitcherTelemetry.pageInterceptEnabled()
                recordSupportEvent(kind: .pageInterceptEnabled, detail: "state=enabled,existingTap=true")
            }
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfRefcon = Unmanaged.passRetained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: pageInterceptCallback,
            userInfo: selfRefcon
        ) else {
            Unmanaged<SwitcherViewModel>.fromOpaque(selfRefcon).release()
            Task { @MainActor [weak self] in
                self?.isPageInterceptEnabled = false
                LiveSwitcherTelemetry.pageInterceptDisabled(reason: "eventTapCreateFailed")
                self?.recordSupportEvent(
                    kind: .pageInterceptDisabled,
                    detail: "reason=eventTapCreateFailed"
                )
                // 弹出权限引导 Alert
                let alert = NSAlert()
                alert.messageText = "PPT模式无法启动"
                alert.informativeText = "翻页笔接管需要「辅助功能」权限。\n\n请前往：系统设置 → 隐私与安全性 → 辅助功能，找到\"LiveSwitcher\"并打开开关。\n\n设置完成后，重新启动 App 再开启 PPT模式。"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "稍后处理")
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            return
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        pageInterceptEventTap = tap
        pageInterceptRunLoopSource = src
        pageInterceptSelfRefcon = selfRefcon
        pageInterceptRuntime.updateEventTap(tap)
        LiveSwitcherTelemetry.pageInterceptEnabled()
        recordSupportEvent(kind: .pageInterceptEnabled, detail: "state=enabled")
    }

    private func stopPageIntercept() {
        if let tap = pageInterceptEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = pageInterceptRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        if let refcon = pageInterceptSelfRefcon {
            Unmanaged<SwitcherViewModel>.fromOpaque(refcon).release()
            pageInterceptSelfRefcon = nil
        }
        pageInterceptEventTap = nil
        pageInterceptRunLoopSource = nil
        pageInterceptRuntime.updateEventTap(nil)
        LiveSwitcherTelemetry.pageInterceptDisabled(reason: "operator")
        recordSupportEvent(kind: .pageInterceptDisabled, detail: "state=disabled,reason=operator")
    }

    nonisolated func reenablePageIntercept(reason: PageInterceptReenableReason) {
        let didReenable = pageInterceptRuntime.reenableEventTap()
        LiveSwitcherTelemetry.pageInterceptAutoReenabled(reason: reason, didReenable: didReenable)
        Task { @MainActor [weak self] in
            self?.recordSupportEvent(
                kind: .pageInterceptAutoReenabled,
                detail: "reason=\(reason.rawValue),reenabled=\(didReenable)"
            )
        }
    }

    /// 处理拦截到的按键，返回 true 表示吞没（nonisolated 供 C 回调调用）
    nonisolated func handlePageInterceptKey(keyCode: CGKeyCode, flags: CGEventFlags = []) -> Bool {
        // HTML bridge only exposes a lock-protected active flag here; WKWebView stays on MainActor.
        switch keyCode {
        case 121, 124: // PageDown / RightArrow → 下一页
            if HTMLWebViewBridge.shared.hasActiveWebView {
                HTMLWebViewBridge.shared.dispatchArrowKey(isNext: true)
            } else {
                sendPageKeyToWPS(isPageDown: true)
            }
            return true
        case 116, 123: // PageUp / LeftArrow → 上一页
            if HTMLWebViewBridge.shared.hasActiveWebView {
                HTMLWebViewBridge.shared.dispatchArrowKey(isNext: false)
            } else {
                sendPageKeyToWPS(isPageDown: false)
            }
            return true
        default:
            return false
        }
    }

    /// 向后台 WPS 进程注入翻页按键（nonisolated，可在 C 回调中调用）
    nonisolated private func sendPageKeyToWPS(isPageDown: Bool) {
        let direction = isPageDown ? "next" : "previous"
        guard let targetPID = wpsApplicationMonitor.currentProcessIdentifier else {
            LiveSwitcherTelemetry.pageInterceptWPSNotRunning(direction: direction)
            Task { @MainActor [weak self] in
                self?.recordSupportEvent(
                    kind: .pageInterceptWPSNotRunning,
                    detail: "direction=\(direction),state=notRunning"
                )
            }
            return
        }
        let keyCode: CGKeyCode = isPageDown ? 121 : 116

        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
            keyDown.postToPid(targetPID)
        }
        if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            keyUp.postToPid(targetPID)
        }
        LiveSwitcherTelemetry.pageInterceptForwardedToWPS(
            direction: direction,
            processIdentifier: targetPID
        )
        Task { @MainActor [weak self] in
            self?.recordSupportEvent(
                kind: .pageInterceptForwardedToWPS,
                detail: "direction=\(direction),target=wps"
            )
        }
    }

    // MARK: - Tier1: 紧急切黑 State
    @Published var isPanicMode: Bool       = false
    @Published var isFadeToBlackActive: Bool = false

    // MARK: - Tier1: Overlay State（叠层状态变量）
    @Published var overlayComposerState = OverlayComposerState()
    @Published var isCountdownActive: Bool = false
    @Published var countdownTitle: String  = "活动即将开始"
    @Published var countdownSeconds: Int   = 0
    @Published var countdownPresets: [CountdownPreset] = []
    var countdownTimer: Timer?

    @Published var isTickerActive: Bool    = false
    @Published var tickerText: String      = "Welcome · The program will begin shortly"
    @Published var tickerSpeed: Double     = 80.0
    @Published var tickerPresets: [TickerPreset] = []

    // MARK: - V27: Lower Third（下三分之一条）状态
    @Published var isLowerThirdVisible: Bool = false
    @Published var lowerThirdName: String    = ""
    @Published var lowerThirdTitle: String   = ""
    @Published var lowerThirdPresets: [LowerThirdPreset] = []
}

// MARK: - V25: 翻页拦截 CGEventTap 全局 C 回调

private func pageInterceptCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let vm = Unmanaged<SwitcherViewModel>.fromOpaque(refcon).takeUnretainedValue()

    switch PageInterceptEventPolicy.action(for: type) {
    case .passThrough:
        return Unmanaged.passUnretained(event)
    case .reenableTap(let reason):
        vm.reenablePageIntercept(reason: reason)
        return Unmanaged.passUnretained(event)
    case .handleKeyDown:
        break
    }

    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags
    if vm.handlePageInterceptKey(keyCode: keyCode, flags: flags) {
        return nil  // 吞没事件
    }
    return Unmanaged.passUnretained(event)
}
