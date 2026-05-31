import SwiftUI
import Observation
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

final class ViewModelCleanupBag {
    var mediaVolumeFadeTask: Task<Void, Never>?
    var bgmPlayerVolumeFadeTask: Task<Void, Never>?
    var bgmFallbackVolumeFadeTask: Task<Void, Never>?
    var bgmProgressTimer: Timer?
    var bgmFallbackEndObserver: NSObjectProtocol?
    var bgmFallbackFailureObserver: NSObjectProtocol?
    var bgmTransitionTasks: [UUID: Task<Void, Never>] = [:]
    var retiredBGMFallbackPlayers: [UUID: AVPlayer] = [:]
    var panicAudioPauseTask: Task<Void, Never>?
    var backgroundImageLoadTask: Task<Void, Never>?
    var cornerLogoImageLoadTask: Task<Void, Never>?
    var systemVolumeObserver: SystemVolumeObserver?
    var externalDisplayChangeObserver: NSObjectProtocol?

    func cancelAll() {
        mediaVolumeFadeTask?.cancel()
        bgmPlayerVolumeFadeTask?.cancel()
        bgmFallbackVolumeFadeTask?.cancel()
        bgmProgressTimer?.invalidate()
        bgmProgressTimer = nil
        bgmTransitionTasks.values.forEach { $0.cancel() }
        retiredBGMFallbackPlayers.values.forEach { player in
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        retiredBGMFallbackPlayers.removeAll()
        panicAudioPauseTask?.cancel()
        backgroundImageLoadTask?.cancel()
        cornerLogoImageLoadTask?.cancel()
        systemVolumeObserver?.stop()
        if let externalDisplayChangeObserver {
            NotificationCenter.default.removeObserver(externalDisplayChangeObserver)
            self.externalDisplayChangeObserver = nil
        }
        if let bgmFallbackEndObserver {
            NotificationCenter.default.removeObserver(bgmFallbackEndObserver)
            self.bgmFallbackEndObserver = nil
        }
        if let bgmFallbackFailureObserver {
            NotificationCenter.default.removeObserver(bgmFallbackFailureObserver)
            self.bgmFallbackFailureObserver = nil
        }
    }

    deinit {
        cancelAll()
    }
}

@MainActor
@Observable
final class SwitcherViewModel {

    // MARK: - 主窗口导航

    var selectedMainTab: MainConsoleTab = .preview
    var consoleMode: ConsoleMode = .setup {
        didSet {
            userDefaults.set(consoleMode.rawValue, forKey: UDKeys.consoleMode)
        }
    }
    var themeOverride: ThemeOverride = .dark {
        didSet {
            userDefaults.set(themeOverride.rawValue, forKey: UDKeys.themeOverride)
        }
    }

    // MARK: - 节目状态

    var currentProgramItem: ProgramItem? {
        didSet {
            let sourceChanged = currentProgramItem?.sourceURL != oldValue?.sourceURL
                || currentProgramItem?.sourceKind != oldValue?.sourceKind
            guard currentProgramItem?.id != oldValue?.id || sourceChanged else { return }
            currentProgramSwitchedAt = currentProgramItem == nil ? nil : Date()
            applyAudioRoutingForRuntimeChange(reason: .programChanged)
        }
    }
    var currentProgramSwitchedAt: Date?
    private var needsMutedMediaStartupAfterClearedProgram = false
    var programItems: [ProgramItem] = []
    var showAgendaTimeline: Bool = false {
        didSet {
            userDefaults.set(showAgendaTimeline, forKey: UDKeys.showAgendaTimeline)
        }
    }

    // MARK: - 推流状态

    var isBroadcasting: Bool = false
    var broadcastSafetyNotice: String?
    var automationRuntimeNotice: AutomationRuntimeNotice?

    // MARK: - HTML 大屏展示

    /// 当前推送到副屏 WKWebView 的 HTML 文件 URL；切换其他节目时清空
    var currentHTMLURL: URL? = nil


    // MARK: - 音量控制（Fix Issue #7/#8: 所有 didSet 在 @MainActor 上安全执行）

    /// 主音量 [0.0, 1.0] - 联控 AVPlayer + BGM
    var masterVolume: Double = 0.5 {
        didSet {
            guard oldValue != masterVolume else { return }
            dispatchRuntimeFacadeAction(.operatorChangedMasterVolume(masterVolume))
            applyMasterVolume()
        }
    }

    /// 媒体源音量 [0.0, 1.0]
    var mediaVolume: Double = 1.0 {
        didSet {
            guard oldValue != mediaVolume else { return }
            dispatchRuntimeFacadeAction(.operatorChangedMediaVolume(mediaVolume))
            applyMasterVolume()
        }
    }

    /// BGM 音量 [0.0, 1.0]
    var bgmVolume: Double = 0.5 {
        didSet {
            guard oldValue != bgmVolume else { return }
            dispatchRuntimeFacadeAction(.operatorChangedBGMVolume(bgmVolume))
            applyBGMVolume()
        }
    }

    /// Live mode mute controls are session-scoped operator actions and are not persisted.
    var isMasterAudioMuted: Bool = false {
        didSet {
            guard oldValue != isMasterAudioMuted else { return }
            dispatchRuntimeFacadeAction(.operatorChangedMasterMute(isMasterAudioMuted))
            applyAudioRoutingForRuntimeChange(reason: .operatorFaderChanged)
        }
    }
    var isMediaAudioMuted: Bool = false {
        didSet {
            guard oldValue != isMediaAudioMuted else { return }
            dispatchRuntimeFacadeAction(.operatorChangedMediaMute(isMediaAudioMuted))
            applyAudioRoutingForRuntimeChange(reason: .operatorFaderChanged)
        }
    }
    var isBGMAudioMuted: Bool = false {
        didSet {
            guard oldValue != isBGMAudioMuted else { return }
            dispatchRuntimeFacadeAction(.operatorChangedBGMMute(isBGMAudioMuted))
            applyAudioRoutingForRuntimeChange(reason: .operatorFaderChanged)
        }
    }

    /// 音频输出策略。默认保持“混合”，与当前已存在的实际行为一致。
    var audioStrategy: AudioStrategy = .mixed {
        didSet {
            guard oldValue != audioStrategy else { return }
            dispatchRuntimeFacadeAction(.operatorSelectedAudioStrategy(audioStrategy))
            applyAudioRoutingForRuntimeChange(reason: .strategyChanged)
            userDefaults.set(audioStrategy.rawValue, forKey: UDKeys.audioStrategy)
        }
    }

    // MARK: - 转场配置

    var crossfadeDuration: Double = 3.0
    var liveAudioFadeDuration: Double = 2.0
    private let speakerModeDuckedRatio: Float = 0.07

    // MARK: - 背景壁纸（多张）

    var backgroundWallpapers: [URL] = []
    var backgroundImage: NSImage?
    var activeWallpaperURL: URL? {
        didSet {
            loadBackgroundImage(from: activeWallpaperURL)
        }
    }
    var cornerLogoURL: URL? {
        didSet {
            loadCornerLogoImage(from: cornerLogoURL)
        }
    }
    var cornerLogoImage: NSImage?
    var cornerLogoPosition: CornerLogoPosition = .topRight {
        didSet {
            userDefaults.set(cornerLogoPosition.rawValue, forKey: UDKeys.cornerLogoPosition)
        }
    }

    // MARK: - BGM 列表

    var bgmItems: [BGMItem] = []
    var currentBGMItem: BGMItem?
    var isBGMPlaying: Bool = false
    var isBGMAudioTakeoverActive: Bool = false {
        didSet {
            guard oldValue != isBGMAudioTakeoverActive else { return }
            dispatchRuntimeFacadeAction(.operatorChangedBGMTakeover(isBGMAudioTakeoverActive))
            applyAudioRoutingForRuntimeChange(reason: .limiterChanged)
        }
    }
    var bgmPlayMode: BGMPlayMode = .loopAll {
        didSet {
            userDefaults.set(bgmPlayMode.rawValue, forKey: UDKeys.bgmPlayMode)
        }
    }
    private(set) var supportEvents: [LiveSupportEvent] = []

    /// V26.3: 主讲人模式（一键压限 BGM）
    var isSpeakerMode: Bool = false {
        didSet {
            userDefaults.set(isSpeakerMode, forKey: UDKeys.speakerMode)
            guard oldValue != isSpeakerMode else { return }
            dispatchRuntimeFacadeAction(.operatorSetSpeakerMode(isSpeakerMode))
            applyAudioRoutingForRuntimeChange(reason: .speakerChanged)
        }
    }

    /// 视频播毕后仅自动播放队列里的紧邻下一条视频；默认关闭，避免现场自动打开演示文件。
    var autoPlayNextVideoOnEnd: Bool = false {
        didSet {
            userDefaults.set(autoPlayNextVideoOnEnd, forKey: UDKeys.autoPlayNextVideoOnEnd)
        }
    }
    var autoAdvanceAtScheduledTime: Bool = false {
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
        set {
            guard let newValue, newValue.isFinite, newValue > 0 else {
                bgmProgressStore.duration = nil
                return
            }
            bgmProgressStore.duration = newValue
        }
    }
    @ObservationIgnored let audioMeterStore = AudioMeterStore()
    @ObservationIgnored var bgmRealtimeLevelDB: Float? = nil

    /// Audio page category selection is retained outside the view tree so live/setup mode switches can unmount hidden setup views.
    var bgmLibraryCategorySelection = BGMCategorySelectionState(selectedCategory: .warmUp)

    /// BGM 播放器
    var bgmAudioPlayer: AVAudioPlayer?
    var bgmFallbackPlayer: AVPlayer = AVPlayer()
    var panicPlaybackSnapshot: PanicPlaybackSnapshot?
    var panicAudioTransitionGeneration: Int = 0
    private(set) var lastAudioRoutingTransition: AudioRoutingTransition?

    // MARK: - 引擎

    let runtime = LiveRuntimeStore()
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
    private(set) var isExternalDisplayAvailable: Bool = false
    var outputWindowControllerFactory: () -> OutputWindowControlling = {
        OutputWindowController() as OutputWindowControlling
    }
    var keynotePresentationHandler: (URL) -> Void = { _ in }
    var pptxOpenHandler: (URL) -> Void = { _ in }
    var deckStopHandler: () -> Void = {}
    var programSeekToStartHandler: () -> Void = {}
    var programRestartFromBeginningHandler: (@escaping () -> Void) -> Void = { _ in }
    var programSeekToEndHandler: () -> Void = {}
    var activeDeckPresentationHandler: () -> Void = {}
    var invalidDeckHandler: (URL) -> Void = { _ in }
    private var isPresentingAutomationAlert = false
    private let automationAlertSuppressionWindow: TimeInterval = 15
    private var automationAlertSuppressionUntilByAction: [String: Date] = [:]
    private let automationNoticeSuppressionWindow: TimeInterval = 15
    private var automationNoticeSuppressionUntilByAction: [String: Date] = [:]
    // MARK: - Combine / Timers

    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored let cleanupBag = ViewModelCleanupBag()
    private var bgmTransitionGeneration: Int = 0
    private let supportEventLimit = 80
    private var agendaAutoAdvancePromptedItemIDs = Set<UUID>()

    // MARK: - V25: 翻页拦截器状态
    /// 翻页笔拦截开关（开启时全局拦截 PageUp/Down/左右箭头并转发给 WPS）
    var isPageInterceptEnabled: Bool = false {
        didSet { applyPageInterceptState() }
    }
    @ObservationIgnored var pageInterceptSideEffectsEnabled = true

    func togglePPTMode(source: PPTModeToggleSource = .programmatic) {
        setPPTMode(PPTModeToggleModel.nextState(isEnabled: isPageInterceptEnabled), source: source)
    }

    func setPPTMode(_ enabled: Bool, source: PPTModeToggleSource = .programmatic) {
        guard enabled != isPageInterceptEnabled else { return }
        dispatchRuntimeFacadeAction(.operatorToggledPPTMode(source: source))
        recordSupportEvent(
            kind: .pptModeChanged,
            detail: "isOn=\(enabled),source=\(source.rawValue)"
        )
        isPageInterceptEnabled = enabled
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
        static let pushListTitles = "pushList_titles"
        static let pushListSubtitles = "pushList_subtitles"
        static let pushListScheduledStarts = "pushList_scheduled_starts"
        static let pushListScheduledDurations = "pushList_scheduled_durations"
        static let bgmList = "bgmList_paths"
        static let bgmListTitles = "bgmList_titles"
        static let bgmListCategories = "bgmList_categories"
        static let bgmPlayMode = "bgmPlayMode"
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
        self.programRestartFromBeginningHandler = { [weak self] onReadyToPlay in
            self?.avCoordinator.restartFromBeginning(onReadyToPlay: onReadyToPlay)
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
        syncRuntimeStateFromFacade(clearActionLog: true)
    }

    deinit {
        let cleanupBag = cleanupBag
        let avCoordinator = avCoordinator

        cleanupBag.cancelAll()
        avCoordinator.shutdownNonisolated()
    }

    // MARK: - Runtime facade bridge

    func dispatchRuntimeFacadeAction(_ action: LiveRuntimeAction) {
        syncRuntimeStateFromFacade(clearActionLog: false)
        runtime.dispatch(action)
    }

    func dispatchRuntimeMediaCallback(_ makeAction: (Int) -> LiveRuntimeAction) {
        syncRuntimeStateFromFacade(clearActionLog: false)
        runtime.dispatch(makeAction(runtime.state.media.generation))
    }

    func dispatchRuntimeBGMCallback(_ makeAction: (Int) -> LiveRuntimeAction) {
        syncRuntimeStateFromFacade(clearActionLog: false)
        runtime.dispatch(makeAction(runtime.state.bgm.generation))
    }

    func dispatchRuntimeBGMProgressCallback(time: Double, duration: Double?) {
        dispatchRuntimeBGMCallback {
            .bgmProgressUpdated(time: time, duration: duration, generation: $0)
        }
    }

    func syncRuntimeStateFromFacade(clearActionLog: Bool) {
        runtime.replaceStateForFacadeSync(makeRuntimeStateSnapshot(), clearActionLog: clearActionLog)
    }

    private func makeRuntimeStateSnapshot() -> LiveRuntimeState {
        var state = runtime.state
        state.mode = consoleMode
        state.program.items = programItems
        state.program.currentID = currentProgramItem?.id
        state.program.currentSwitchedAt = currentProgramSwitchedAt

        state.media.loadedURL = avCoordinator.currentURL
        state.media.isPlaying = avCoordinator.isPlaying
        state.media.currentTime = avCoordinator.currentTime
        state.media.duration = avCoordinator.duration

        state.bgm.items = bgmItems
        state.bgm.currentID = currentBGMItem?.id
        state.bgm.isPlaying = isBGMPlaying
        state.bgm.playMode = bgmPlayMode
        state.bgm.progress = bgmProgress
        state.bgm.currentTime = bgmCurrentTime
        state.bgm.duration = bgmDuration

        state.audio.masterVolume = masterVolume
        state.audio.mediaVolume = mediaVolume
        state.audio.bgmVolume = bgmVolume
        state.audio.strategy = audioStrategy
        state.audio.isMasterMuted = isMasterAudioMuted
        state.audio.isMediaMuted = isMediaAudioMuted
        state.audio.isBGMMuted = isBGMAudioMuted
        state.audio.isSpeakerMode = isSpeakerMode
        state.audio.isBGMTakeoverActive = isBGMAudioTakeoverActive
        state.audio.effectiveMedia = effectiveMediaOutputVolume()
        state.audio.effectiveBGM = effectiveBGMOutputVolume()

        state.panic.isActive = isPanicMode
        state.panic.snapshot = panicPlaybackSnapshot

        state.ppt.isRequested = isPageInterceptEnabled
        state.ppt.isEventTapActive = pageInterceptEventTap != nil

        state.projection.isBroadcasting = isBroadcasting
        state.projection.hasExternalDisplay = isExternalDisplayAvailable
        state.projection.safetyNotice = broadcastSafetyNotice

        state.automation.notice = automationRuntimeNotice
        state.support.events = supportEvents
        return state
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
            cleanupBag.mediaVolumeFadeTask?.cancel()
            avCoordinator.volume = effectiveMedia
        }

        let effectiveBGM = appliedBGMOutputVolume()
        if let bgmFadeDuration, bgmAudioPlayer != nil {
            fadeBGMPlayerVolume(to: effectiveBGM, duration: bgmFadeDuration)
        } else {
            cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
            bgmAudioPlayer?.volume = effectiveBGM
        }

        if let bgmFadeDuration {
            fadeBGMFallbackVolume(to: effectiveBGM, duration: bgmFadeDuration)
        } else {
            cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
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

    var bgmTransitionGenerationForTesting: Int {
        bgmTransitionGeneration
    }

    var bgmProgressTimerForTesting: Timer? {
        cleanupBag.bgmProgressTimer
    }

    func invalidateBGMTransitionGeneration() {
        bgmTransitionGeneration += 1
    }

    private func fadeMediaVolume(to targetVolume: Float, duration: Double) {
        cleanupBag.mediaVolumeFadeTask?.cancel()
        guard duration > 0 else {
            avCoordinator.volume = targetVolume
            return
        }

        cleanupBag.mediaVolumeFadeTask = Task { @MainActor [weak self] in
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
        cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
        guard duration > 0 else {
            bgmFallbackPlayer.volume = targetVolume
            return
        }

        cleanupBag.bgmFallbackVolumeFadeTask = Task { @MainActor [weak self] in
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
        cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
        guard let player = bgmAudioPlayer else { return }
        guard duration > 0 else {
            player.volume = targetVolume
            return
        }

        cleanupBag.bgmPlayerVolumeFadeTask = Task { @MainActor [weak self, weak player] in
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
        cleanupBag.bgmTransitionTasks[taskID] = Task { @MainActor [weak self, weak player] in
            defer { self?.cleanupBag.bgmTransitionTasks[taskID] = nil }
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
        let generation = bgmTransitionGeneration
        cleanupBag.bgmFallbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor [weak self, weak item] in
                guard let self,
                      let item,
                      self.bgmTransitionGeneration == generation,
                      self.bgmFallbackPlayer.currentItem === item
                else { return }
                self.bgmDidFinish()
            }
        }
        cleanupBag.bgmFallbackFailureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor [weak self, weak item] in
                guard let self,
                      let item,
                      self.bgmTransitionGeneration == generation,
                      self.bgmFallbackPlayer.currentItem === item
                else { return }
                self.bgmDidFail()
            }
        }
    }

    func removeBGMFallbackEndObserver() {
        if let observer = cleanupBag.bgmFallbackEndObserver {
            NotificationCenter.default.removeObserver(observer)
            self.cleanupBag.bgmFallbackEndObserver = nil
        }
        if let observer = cleanupBag.bgmFallbackFailureObserver {
            NotificationCenter.default.removeObserver(observer)
            self.cleanupBag.bgmFallbackFailureObserver = nil
        }
    }

    private func runLinearFade(
        from startVolume: Float,
        to targetVolume: Float,
        duration: Double,
        apply: @escaping (Float) -> Void
    ) async {
        let steps = AudioFadeStepPolicy.stepCount(duration: duration)
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
        cleanupBag.backgroundImageLoadTask?.cancel()
        guard let url else {
            backgroundImage = nil
            return
        }
        backgroundImage = NSImage(byReferencing: url)
        cleanupBag.backgroundImageLoadTask = Task { @MainActor [weak self] in
            let data = await Self.imageData(from: url)
            guard !Task.isCancelled, let self, self.activeWallpaperURL == url else { return }
            self.backgroundImage = data.flatMap(NSImage.init(data:))
        }
    }

    private func loadCornerLogoImage(from url: URL?) {
        cleanupBag.cornerLogoImageLoadTask?.cancel()
        guard let url else {
            cornerLogoImage = nil
            return
        }
        cornerLogoImage = NSImage(byReferencing: url)
        cleanupBag.cornerLogoImageLoadTask = Task { @MainActor [weak self] in
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
        cleanupBag.externalDisplayChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
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
        userDefaults.set(pushTitles, forKey: UDKeys.pushListTitles)
        userDefaults.set(pushSubtitles, forKey: UDKeys.pushListSubtitles)
        userDefaults.set(pushScheduledStarts, forKey: UDKeys.pushListScheduledStarts)
        userDefaults.set(pushScheduledDurations, forKey: UDKeys.pushListScheduledDurations)

        let bgmPaths = bgmItems.map { $0.url.path }
        let bgmCategories = bgmItems.map { $0.category.rawValue }
        let bgmTitles = bgmItems.map { $0.title }
        userDefaults.set(bgmPaths, forKey: UDKeys.bgmList)
        userDefaults.set(bgmCategories, forKey: UDKeys.bgmListCategories)
        userDefaults.set(bgmTitles, forKey: UDKeys.bgmListTitles)

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
        // Fix Issue #2: loadData is called from @MainActor init, all state updates are safe
        if let paths = userDefaults.stringArray(forKey: UDKeys.pushList) {
            let titles = userDefaults.stringArray(forKey: UDKeys.pushListTitles) ?? []
            let subtitles = userDefaults.stringArray(forKey: UDKeys.pushListSubtitles) ?? []
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
            let titles = userDefaults.stringArray(forKey: UDKeys.bgmListTitles) ?? []
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
            backgroundWallpapers = paths.compactMap { path -> URL? in
                let url = URL(fileURLWithPath: path)
                return WallpaperImagePolicy.isRenderableImage(url: url) ? url : nil
            }
            let droppedCount = paths.count - backgroundWallpapers.count
            if droppedCount > 0 {
                recordSupportEvent(kind: .wallpaperFileMissing, detail: "count=\(droppedCount)")
                userDefaults.set(backgroundWallpapers.map(\.path), forKey: UDKeys.wallpapers)
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
            if let activeWallpaperURL {
                userDefaults.set(activeWallpaperURL.path, forKey: UDKeys.activeWallpaper)
            } else {
                userDefaults.removeObject(forKey: UDKeys.activeWallpaper)
            }
        }

        if let rawPosition = userDefaults.string(forKey: UDKeys.cornerLogoPosition),
           let position = CornerLogoPosition(rawValue: rawPosition) {
            cornerLogoPosition = position
        }
        if let logoPath = userDefaults.string(forKey: UDKeys.cornerLogo) {
            let logoURL = URL(fileURLWithPath: logoPath)
            if WallpaperImagePolicy.isRenderableImage(url: logoURL) {
                cornerLogoURL = logoURL
            } else {
                cornerLogoURL = nil
                userDefaults.removeObject(forKey: UDKeys.cornerLogo)
            }
        }

        if let storedAudioStrategy = userDefaults.string(forKey: UDKeys.audioStrategy),
           let audioStrategy = AudioStrategy(persistedValue: storedAudioStrategy) {
            self.audioStrategy = audioStrategy
        }

        if let rawPlayMode = userDefaults.string(forKey: UDKeys.bgmPlayMode),
           let storedPlayMode = BGMPlayMode(rawValue: rawPlayMode) {
            bgmPlayMode = storedPlayMode
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
            .sink { [weak self] isPlaying in
                self?.dispatchRuntimeMediaCallback {
                    .mediaPlaybackChanged(isPlaying: isPlaying, generation: $0)
                }
                self?.applyAudioRoutingForRuntimeChange(reason: .mediaPlaybackChanged)
            }
            .store(in: &cancellables)

        avCoordinator.onPlaybackEnded = { [weak self] in
            self?.handlePlaybackEnded()
        }
    }

    // MARK: - 节目操作

    func switchToProgram(_ item: ProgramItem) {
        guard programSourceIsAvailable(item) else { return }
        guard item.sourceKind.isActivatableProgram else { return }
        dispatchRuntimeFacadeAction(.operatorSelectedProgram(item.id))

        switch item.sourceKind {
        case .agendaMarker, .unsupported:
            return
        case .media:
            guard let url = item.sourceURL else { return }
            stopCurrentDeckPresentationIfNeeded(before: item)
            let isReplacingLoadedMedia = avCoordinator.hasLoadedMedia
            let isStartingFreshMediaProgram = currentProgramItem == nil && !isReplacingLoadedMedia
            let isReplacingNonMediaProgram = currentProgramItem != nil && currentProgramItem?.sourceKind != .media
            let needsMutedClearedProgramStartup = needsMutedMediaStartupAfterClearedProgram
            currentHTMLURL = nil              // 清空 HTML 层
            avCoordinator.load(url: url)
            if liveAudioFadeDuration > 0
                && ((isStartingFreshMediaProgram && isBGMPlaying)
                    || isReplacingLoadedMedia || isReplacingNonMediaProgram || needsMutedClearedProgramStartup) {
                // 避免新媒体在 currentProgramItem 更新前继承上一条媒体音量；programChanged 会淡入到目标值。
                avCoordinator.volume = 0
            }
            if isPanicMode {
                avCoordinator.pause()
            } else {
                avCoordinator.play()
            }
            needsMutedMediaStartupAfterClearedProgram = false
            currentProgramItem = item
        case .keynote:
            guard let url = item.sourceURL else { return }
            if !isLikelyValidDeckDocument(url: url, sourceKind: .keynote) {
                invalidDeckHandler(url)
                return
            }
            stopCurrentDeckPresentationIfNeeded(before: item)
            currentProgramItem = item
            currentHTMLURL = nil              // 清空 HTML 层
            avCoordinator.stop()              // 清空旧视频，避免副屏/监视器残留上一条节目
            keynotePresentationHandler(url)
        case .pptx:
            guard let url = item.sourceURL else { return }
            if !isLikelyValidDeckDocument(url: url, sourceKind: .pptx) {
                invalidDeckHandler(url)
                return
            }
            stopCurrentDeckPresentationIfNeeded(before: item)
            currentProgramItem = item
            currentHTMLURL = nil              // 清空 HTML 层
            avCoordinator.stop()              // 清空旧视频，避免副屏/监视器残留上一条节目
            pptxOpenHandler(url)
        case .html:
            guard let url = item.sourceURL else { return }
            stopCurrentDeckPresentationIfNeeded(before: item)
            currentProgramItem = item
            avCoordinator.stop()              // Bug3修复：stop清空currentURL，监视器不再显示视频
            openHTMLInOutputWindow(url: url)
        case .activeDeck:
            stopCurrentDeckPresentationIfNeeded(before: item)
            currentProgramItem = item
            currentHTMLURL = nil
            avCoordinator.stop()
            activeDeckPresentationHandler()
        }
    }

    private func stopCurrentDeckPresentationIfNeeded(before nextItem: ProgramItem) {
        guard let currentProgramItem,
              currentProgramItem.id != nextItem.id,
              currentProgramItem.supportsPresentationControl
        else { return }
        deckStopHandler()
    }

    private func programSourceIsAvailable(_ item: ProgramItem) -> Bool {
        switch item.sourceKind {
        case .media, .html, .keynote, .pptx:
            guard let url = item.sourceURL else {
                handleUnavailableProgramSource(item, reason: "sourceURLMissing")
                return false
            }
            guard FileManager.default.fileExists(atPath: url.path) else {
                handleUnavailableProgramSource(item, reason: "fileMissing")
                return false
            }
            return true
        case .activeDeck, .agendaMarker, .unsupported:
            return true
        }
    }

    private func handleUnavailableProgramSource(_ item: ProgramItem, reason: String) {
        recordSupportEvent(
            kind: .programItemFileMissing,
            detail: "sourceKind=\(programSourceKindSupportLabel(item.sourceKind)),reason=\(reason)"
        )
        showAutomationRuntimeNotice(action: "program.source.missing")
    }

    private func programSourceKindSupportLabel(_ kind: ProgramSourceKind) -> String {
        switch kind {
        case .media:
            return "media"
        case .html:
            return "html"
        case .keynote:
            return "keynote"
        case .pptx:
            return "pptx"
        case .activeDeck:
            return "activeDeck"
        case .agendaMarker:
            return "agendaMarker"
        case .unsupported:
            return "unsupported"
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

    private func isLikelyValidDeckDocument(url: URL, sourceKind: ProgramSourceKind) -> Bool {
        PresentationDocumentValidator.isLikelyValid(url: url, sourceKind: sourceKind)
    }

    private func presentInvalidDeckAlert(for url: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "当前演示文件无效"
        alert.informativeText = "“\(url.lastPathComponent)” 不是可直接播放的演示文稿，已阻止发送到输出。请删除这条节目，或重新导入真实的 Keynote / PowerPoint 文件。"
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    private func runAutomationScript(_ source: String, action: String) {
        Task { @MainActor [weak self] in
            do {
                try AppleScriptRunner.run(source, action: action)
            } catch {
                self?.handleAppleScriptFailure(error, action: action)
            }
        }
    }

    func handleAppleScriptFailure(_ error: Error, action: String) {
        let message = appleScriptFailureMessage(error)
        dispatchRuntimeFacadeAction(.automationFailed(action: action, sanitizedMessage: message))
        recordSupportEvent(kind: .appleScriptFailed, detail: "action=\(action),error=\(message)")
        automationRuntimeNotice = runtime.state.automation.notice
    }

    func dismissAutomationRuntimeNotice() {
        dispatchRuntimeFacadeAction(.automationNoticeDismissed)
        automationRuntimeNotice = nil
    }

    func expireAutomationRuntimeNotice(id: UUID, now: Date = Date()) {
        guard let notice = automationRuntimeNotice,
              notice.id == id,
              let expiresAt = notice.expiresAt,
              now >= expiresAt
        else { return }
        dispatchRuntimeFacadeAction(.automationNoticeExpired(id))
        automationRuntimeNotice = nil
    }

    private func showAutomationRuntimeNotice(action: String, now: Date = Date()) {
        if let suppressionUntil = automationNoticeSuppressionUntilByAction[action],
           now < suppressionUntil {
            return
        }

        automationRuntimeNotice = AutomationRuntimeNoticePolicy.make(action: action, createdAt: now)
        automationNoticeSuppressionUntilByAction[action] = now
            .addingTimeInterval(automationNoticeSuppressionWindow)
    }

    private func presentAutomationAlert(
        title: String,
        message: String,
        action: String,
        primaryButton: String,
        secondaryButton: String,
        primaryAction: (() -> Void)?
    ) {
        performAutomationAlert(action: action) {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: primaryButton)
            alert.addButton(withTitle: secondaryButton)
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                primaryAction?()
            }
        }
    }

    private func performAutomationAlert(action: String, _ present: () -> Void) {
        guard canPresentAutomationAlert(action: action) else { return }
        isPresentingAutomationAlert = true
        defer {
            isPresentingAutomationAlert = false
            automationAlertSuppressionUntilByAction[action] = Date()
                .addingTimeInterval(automationAlertSuppressionWindow)
        }
        present()
    }

    private func canPresentAutomationAlert(action: String, now: Date = Date()) -> Bool {
        guard !isPresentingAutomationAlert else { return false }
        if let suppressionUntil = automationAlertSuppressionUntilByAction[action],
           now < suppressionUntil {
            return false
        }
        return true
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

    private static func openWithWPSOffice(url: URL) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: AppConfiguration.wpsBundleIdentifier
        ) else {
            throw AppleScriptError.executionFailed(
                action: "wps.open.command",
                message: "WPS Office application was not found"
            )
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: appURL,
                configuration: configuration
            ) { _, error in
                if let error {
                    continuation.resume(throwing: AppleScriptError.executionFailed(
                        action: "wps.open.command",
                        message: error.localizedDescription
                    ))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// 将 HTML 文件推送到副屏 WKWebView
    func openHTMLInOutputWindow(url: URL) {
        currentHTMLURL = url
        // Observation tracks currentHTMLURL changes; no manual invalidation is needed.
    }

    /// 结束 HTML 展示，回到空闲壁纸态。
    func endHTMLPresentation() {
        currentHTMLURL = nil
        currentProgramItem = nil
    }

    /// 当前节目播毕后的最小状态回退。
    func handlePlaybackEnded() {
        dispatchRuntimeMediaCallback { .mediaReachedEnd(generation: $0) }
        LiveSwitcherTelemetry.playbackReachedEnd()
        recordSupportEvent(kind: .playbackReachedEnd, detail: "state=ended")

        guard !isPanicMode else {
            if panicPlaybackSnapshot?.currentProgramID == currentProgramItem?.id {
                panicPlaybackSnapshot?.wasMediaPlaying = false
            }
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
        return currentProgramItem?.id == nextItem.id
    }

    /// Fix Issue #3: 打开并立即放映 Keynote 文件
    func openAndPresentKeynote(url: URL) {
        let script = PresentationAutomationService.keynoteStartScript(url: url)
        runAutomationScript(
            script,
            action: "keynote.open.present"
        )
    }

    /// V24 Fix #3: PPTX → 默认调取 WPS Office 执行播放（彻底替换 Keynote 调用逻辑）
    func openPPTXWithKeynote(url: URL) {
        Task { @MainActor [weak self] in
            // 优先尝试 WPS Office
            let wpsScript = PresentationAutomationService.wpsOpenScript(url: url)
            do {
                try AppleScriptRunner.run(wpsScript, action: "wps.open.script")
                return
            } catch {
                self?.handleAppleScriptFailure(error, action: "wps.open.script")
            }

            // WPS AppleScript 不可用时，降级用 NSWorkspace 打开 WPS，避免沙盒下调用 /usr/bin/open。
            do {
                try await Self.openWithWPSOffice(url: url)
            } catch {
                self?.handleAppleScriptFailure(error, action: "wps.open.command")
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
            action: "keynote.present.front"
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
            action: "keynote.next-slide"
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
            action: "keynote.previous-slide"
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
                let cleanName = KeynoteController.cleanedDocumentTitle(from: name)
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
                dispatchRuntimeFacadeAction(.operatorToggledMediaPlayback)
                if panicPlaybackSnapshot?.currentProgramID == item.id {
                    panicPlaybackSnapshot?.wasMediaPlaying = false
                }
                avCoordinator.pause()
                applyAudioRoutingForRuntimeChange(reason: .mediaPlaybackChanged)
            }
            return
        }

        // 普通视频
        dispatchRuntimeFacadeAction(.operatorToggledMediaPlayback)
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
            action: "keynote.stop.presentation"
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
        dispatchRuntimeFacadeAction(.operatorRestartedCurrentMedia)
        if isPanicMode {
            programSeekToStartHandler()
            applyAudioRoutingForRuntimeChange(reason: .mediaPlaybackChanged)
        } else {
            programRestartFromBeginningHandler { [weak self] in
                self?.applyAudioRoutingForRuntimeChange(reason: .mediaPlaybackChanged)
            }
        }
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
            needsMutedMediaStartupAfterClearedProgram = currentProgramItem?.sourceKind == .media
            if currentProgramItem?.supportsPresentationControl == true {
                deckStopHandler()
            }
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
        guard WallpaperImagePolicy.isRenderableImage(url: url) else { return false }
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
        guard WallpaperImagePolicy.isRenderableImage(url: url) else { return false }
        cornerLogoURL = url
        saveData()
        return true
    }

    func removeCornerLogo() {
        cornerLogoURL = nil
        saveData()
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
            dispatchRuntimeFacadeAction(.operatorStoppedBGM)
            bgmTransitionGeneration += 1
            let generation = bgmTransitionGeneration
            let fadeDur = liveAudioFadeDuration
            stopBGMTimer()
            clearBGMTakeoverIfNeeded()
            fadeMediaVolume(to: effectiveMediaOutputVolume(), duration: fadeDur)
            if let removedPlayer = bgmAudioPlayer {
                fadeBGMPlayerVolume(removedPlayer, to: 0, duration: fadeDur)
                removedPlayer.delegate = nil
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
        bgmProgressStore.update(currentTime: 0, duration: bgmAudioPlayer?.duration ?? fallbackBGMKnownDuration() ?? 0)
    }

    func seekBGM(toProgress progress: Double) {
        let clampedProgress = BGMProgressStore.clampedProgress(progress)
        guard let player = bgmAudioPlayer else {
            guard let duration = fallbackBGMKnownDuration(), duration > 0 else {
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

    private func fallbackBGMKnownDuration() -> Double? {
        BGMFallbackDurationPolicy.knownDuration(
            storedDuration: bgmDuration,
            itemDuration: bgmFallbackPlayer.currentItem?.duration.seconds
        )
    }

    private func rewindBGMIfAtEndBeforeResume() {
        let endTolerance = 0.05
        if let player = bgmAudioPlayer, player.duration > 0 {
            let restartThreshold = max(0, player.duration - endTolerance)
            if player.currentTime >= restartThreshold {
                player.currentTime = 0
                bgmProgressStore.update(currentTime: 0, duration: player.duration)
            }
        }

        guard let duration = fallbackBGMKnownDuration(), duration > 0 else { return }
        let currentTime = bgmFallbackPlayer.currentTime().seconds
        guard currentTime.isFinite else { return }
        let restartThreshold = max(0, duration - endTolerance)
        if currentTime >= restartThreshold {
            bgmFallbackPlayer.seek(to: .zero)
            bgmProgressStore.update(currentTime: 0, duration: duration)
        }
    }

    func toggleBGM(_ item: BGMItem) {
        guard !isPanicMode else {
            cueBGMDuringPanic(item)
            return
        }

        if currentBGMItem?.id == item.id {
            if isBGMPlaying {
                // BGM 停止时只解除临时接管，不改变用户选择的混音策略。
                dispatchRuntimeFacadeAction(.operatorStoppedBGM)
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
                if bgmAudioPlayer == nil && bgmFallbackPlayer.currentItem == nil {
                    currentBGMItem = nil
                    toggleBGM(item)
                    return
                }
                // BGM 恢复播放只启动音乐通道；实际路由继续由用户选择的 audioStrategy 决定。
                dispatchRuntimeFacadeAction(.operatorSelectedBGM(item.id))
                bgmTransitionGeneration += 1
                rewindBGMIfAtEndBeforeResume()
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
            dispatchRuntimeFacadeAction(.operatorSelectedBGM(item.id))
            stopBGMTimer()
            bgmTransitionGeneration += 1
            let fadeDur = liveAudioFadeDuration

            // 切歌时取消旧 fallback fade，避免旧任务回写新曲目的目标音量。
            cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
            cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
            if let oldPlayer = bgmAudioPlayer {
                fadeBGMPlayerVolume(oldPlayer, to: 0, duration: fadeDur)
                releaseBGMPlayerAfterFade(oldPlayer, duration: fadeDur)
            }
            bgmAudioPlayer?.delegate = nil
            bgmAudioPlayer = nil
            resetBGMRealtimeMeter()
            removeBGMFallbackEndObserver()
            retireCurrentBGMFallbackPlayerForSwitch(duration: fadeDur)

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
        dispatchRuntimeFacadeAction(.operatorSelectedBGM(item.id))
        stopBGMTimer()
        resetBGMRealtimeMeter()
        clearBGMTakeoverIfNeeded()
        bgmTransitionGeneration += 1
        if panicPlaybackSnapshot?.currentBGMID == item.id {
            panicPlaybackSnapshot?.wasBGMPlaying = false
        }
        bgmAudioPlayer?.delegate = nil
        bgmAudioPlayer = nil
        cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
        cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
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
        let generation = bgmTransitionGeneration
        cleanupBag.bgmProgressTimer = Timer.scheduledTimer(withTimeInterval: BGMProgressStore.updateInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.bgmTransitionGeneration == generation else { return }
                self.updateBGMProgress()
            }
        }
    }

    func stopBGMTimer() {
        cleanupBag.bgmProgressTimer?.invalidate()
        cleanupBag.bgmProgressTimer = nil
    }

    private func releaseBGMPlayerAfterFade(_ player: AVAudioPlayer, duration: Double) {
        let taskID = UUID()
        cleanupBag.bgmTransitionTasks[taskID] = Task { @MainActor [weak self] in
            defer { self?.cleanupBag.bgmTransitionTasks[taskID] = nil }
            let releaseDelay = BGMFadeCompletionPolicy.pauseDelay(fadeDuration: duration)
            if releaseDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(releaseDelay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            player.delegate = nil
            player.stop()
        }
    }

    private func releaseBGMFallbackAfterFade(duration: Double, generation: Int) {
        let taskID = UUID()
        cleanupBag.bgmTransitionTasks[taskID] = Task { @MainActor [weak self] in
            defer { self?.cleanupBag.bgmTransitionTasks[taskID] = nil }
            let releaseDelay = BGMFadeCompletionPolicy.pauseDelay(fadeDuration: duration)
            if releaseDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(releaseDelay * 1_000_000_000))
            }
            guard let self, !Task.isCancelled, self.bgmTransitionGeneration == generation else { return }
            guard self.currentBGMItem == nil, !self.isBGMPlaying else { return }
            self.bgmFallbackPlayer.volume = 0
            self.bgmFallbackPlayer.pause()
            self.removeBGMFallbackEndObserver()
            self.bgmFallbackPlayer.replaceCurrentItem(with: nil)
        }
    }

    private func retireCurrentBGMFallbackPlayerForSwitch(duration: Double) {
        guard bgmFallbackPlayer.currentItem != nil else { return }

        let player = bgmFallbackPlayer
        let taskID = UUID()
        cleanupBag.retiredBGMFallbackPlayers[taskID] = player
        bgmFallbackPlayer = AVPlayer()

        cleanupBag.bgmTransitionTasks[taskID] = Task { @MainActor [weak self, weak player] in
            defer {
                self?.cleanupBag.bgmTransitionTasks[taskID] = nil
                self?.cleanupBag.retiredBGMFallbackPlayers[taskID] = nil
            }
            guard let self, let player else { return }
            if duration > 0 {
                await self.runLinearFade(
                    from: player.volume,
                    to: 0,
                    duration: duration
                ) { [weak player] volume in
                    player?.volume = volume
                }
            } else {
                player.volume = 0
            }
            guard !Task.isCancelled else { return }
            player.volume = 0
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }

    func cancelBGMFallbackFade() {
        cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
        cleanupBag.bgmFallbackVolumeFadeTask = nil
    }

    private func updateBGMProgress() {
        if let player = bgmAudioPlayer {
            let currentTime = player.currentTime
            let duration = player.duration
            bgmProgressStore.update(currentTime: currentTime, duration: duration)
            dispatchRuntimeBGMProgressCallback(time: currentTime, duration: duration)
            updateBGMRealtimeMeter(from: player)
            finishBGMIfProgressReachedEnd(currentTime: currentTime, duration: duration)
        } else if isBGMPlaying {
            let fallbackTime = bgmFallbackPlayer.currentTime().seconds
            let itemDuration = bgmFallbackPlayer.currentItem?.duration.seconds
            let fallbackDuration = bgmDuration ?? ((itemDuration ?? 0) > 0 && itemDuration?.isFinite == true ? itemDuration : nil)
            if fallbackTime.isFinite, let fallbackDuration, fallbackDuration > 0 {
                bgmProgressStore.update(currentTime: fallbackTime, duration: fallbackDuration)
                dispatchRuntimeBGMProgressCallback(time: fallbackTime, duration: fallbackDuration)
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
        audioMeterStore.resetBGMRealtimeLevel()
    }

    private func updateBGMRealtimeMeter(from player: AVAudioPlayer) {
        guard player.isMeteringEnabled, player.numberOfChannels > 0 else {
            resetBGMRealtimeMeter()
            return
        }

        player.updateMeters()
        let level = player.averagePower(forChannel: 0)
        bgmRealtimeLevelDB = level
        audioMeterStore.updateBGMRealtimeLevel(level)
    }

    // MARK: - 推流控制

    func handleBroadcastToggle() {
        dispatchRuntimeFacadeAction(.operatorToggledProjection)
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
            guard isBroadcasting else { return }
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
                    .environment(self)
            )
            outputWindowController?.mountAnyView(rootView: outputView)
        }
        broadcastSafetyNotice = nil
        outputWindowController?.show(on: targetScreen)
    }

    func hideOutputWindow() {
        outputWindowController?.hide()
    }

    func handleExternalDisplayLost() {
        guard isBroadcasting else { return }
        dispatchRuntimeFacadeAction(.projectionExternalDisplayLost)
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
        let event = LiveSupportEvent(timestamp: timestamp, kind: kind, detail: detail)
        if shouldCoalesceSupportEvent(kind),
           let existingIndex = supportEvents.lastIndex(where: {
               $0.kind == kind
                   && supportEventCoalescingKey(kind: kind, detail: $0.detail)
                   == supportEventCoalescingKey(kind: kind, detail: event.detail)
           }) {
            let existing = supportEvents.remove(at: existingIndex)
            let count = supportEventCoalescedCount(existing.detail) + 1
            supportEvents.append(
                LiveSupportEvent(
                    timestamp: timestamp,
                    kind: kind,
                    detail: "\(event.detail),count=\(count),lastSeen=\(Int(timestamp.timeIntervalSince1970))"
                )
            )
        } else {
            supportEvents.append(event)
        }
        if supportEvents.count > supportEventLimit {
            supportEvents.removeFirst(supportEvents.count - supportEventLimit)
        }
    }

    private func shouldCoalesceSupportEvent(_ kind: LiveSupportEventKind) -> Bool {
        switch kind {
        case .appleScriptFailed, .pageInterceptWPSNotRunning, .pageInterceptForwardedToWPS:
            return true
        default:
            return false
        }
    }

    private func supportEventCoalescingKey(kind: LiveSupportEventKind, detail: String) -> String {
        supportEventBaseDetail(detail)
    }

    private func supportEventBaseDetail(_ detail: String) -> String {
        guard let range = detail.range(of: ",count=", options: .backwards) else {
            return detail
        }
        return String(detail[..<range.lowerBound])
    }

    private func supportEventCoalescedCount(_ detail: String) -> Int {
        guard let range = detail.range(of: ",count=", options: .backwards) else {
            return 1
        }
        let suffix = detail[range.upperBound...]
        let digits = suffix.prefix(while: \.isNumber)
        guard let count = Int(digits) else { return 1 }
        return max(count, 1)
    }

    // MARK: - System Volume Observer

    private func setupSystemVolumeObserver() {
        guard cleanupBag.systemVolumeObserver == nil else { return }
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
        cleanupBag.systemVolumeObserver = observer
        observer.start()
    }

    // MARK: - V25: 翻页拦截器控制

    /// 开关翻页拦截（isPageInterceptEnabled didSet 驱动）
    private func applyPageInterceptState() {
        guard pageInterceptSideEffectsEnabled else { return }
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
                guard let self else { return }
                self.isPageInterceptEnabled = false
                self.recordSupportEvent(
                    kind: .pageInterceptDisabled,
                    detail: "reason=accessibilityPermission"
                )
                self.presentAutomationAlert(
                    title: "PPT模式需要辅助功能权限",
                    message: "翻页笔接管需要「辅助功能」权限才能工作。\n\n请前往：系统设置 → 隐私与安全性 → 辅助功能，找到\"LiveSwitcher\"并打开开关。\n\n设置完成后，重新启动 App 即可使用 PPT模式。",
                    action: "pageIntercept.accessibilityPermission",
                    primaryButton: "打开系统设置",
                    secondaryButton: "稍后处理"
                ) {
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
                dispatchRuntimeFacadeAction(.pptEventTapStarted)
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
                guard let self else { return }
                self.dispatchRuntimeFacadeAction(.pptEventTapFailed(reason: "eventTapCreateFailed"))
                self.isPageInterceptEnabled = false
                LiveSwitcherTelemetry.pageInterceptDisabled(reason: "eventTapCreateFailed")
                self.recordSupportEvent(
                    kind: .pageInterceptDisabled,
                    detail: "reason=eventTapCreateFailed"
                )
                self.presentAutomationAlert(
                    title: "PPT模式无法启动",
                    message: "翻页笔接管需要「辅助功能」权限。\n\n请前往：系统设置 → 隐私与安全性 → 辅助功能，找到\"LiveSwitcher\"并打开开关。\n\n设置完成后，重新启动 App 再开启 PPT模式。",
                    action: "pageIntercept.eventTapCreateFailed",
                    primaryButton: "打开系统设置",
                    secondaryButton: "稍后处理"
                ) {
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
        dispatchRuntimeFacadeAction(.pptEventTapStarted)
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
        dispatchRuntimeFacadeAction(.pptEventTapStopped(reason: .operatorDisabled))
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
                self?.showAutomationRuntimeNotice(action: "wps.page.\(direction)")
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
    var isPanicMode: Bool       = false
    var isFadeToBlackActive: Bool = false

    // MARK: - Tier1: Overlay State（叠层状态变量）
    var overlayComposerState = OverlayComposerState()
    var isCountdownActive: Bool = false
    var countdownTitle: String  = "活动即将开始"
    var countdownSeconds: Int   = 0
    var countdownPresets: [CountdownPreset] = []
    var countdownTimer: Timer?

    var isTickerActive: Bool    = false
    var tickerText: String      = "Welcome · The program will begin shortly"
    var tickerSpeed: Double     = 80.0
    var tickerPresets: [TickerPreset] = []

    // MARK: - V27: Lower Third（下三分之一条）状态
    var isLowerThirdVisible: Bool = false
    var lowerThirdName: String    = ""
    var lowerThirdTitle: String   = ""
    var lowerThirdPresets: [LowerThirdPreset] = []
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
