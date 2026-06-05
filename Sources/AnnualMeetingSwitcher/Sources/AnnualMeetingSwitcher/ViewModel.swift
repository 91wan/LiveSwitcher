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

@MainActor
@Observable
final class SwitcherViewModel {

    // MARK: - 主窗口导航

    var selectedMainTab: MainConsoleTab = .preview
    var consoleMode: ConsoleMode = .setup {
        didSet {
            dispatchRuntimeFacadeAction(.operatorSetConsoleMode(consoleMode))
        }
    }
    var themeOverride: ThemeOverride = .dark {
        didSet {
            dispatchRuntimeFacadeAction(.operatorSetThemeOverride(themeOverride))
        }
    }

    // MARK: - 节目状态

    var currentProgramItem: ProgramItem? {
        didSet {
            let sourceChanged = currentProgramItem?.sourceURL != oldValue?.sourceURL
                || currentProgramItem?.sourceKind != oldValue?.sourceKind
            guard currentProgramItem?.id != oldValue?.id || sourceChanged else { return }
            currentProgramSwitchedAt = currentProgramItem == nil ? nil : Date()
            guard !suppressCurrentProgramFacadeDispatch else { return }
            dispatchRuntimeFacadeAction(.facadeCurrentProgramChanged(currentProgramItem?.id))
        }
    }
    var currentProgramSwitchedAt: Date?
    @ObservationIgnored private var suppressCurrentProgramFacadeDispatch = false
    @ObservationIgnored var activeRuntimeMediaGenerationForCallbacks: Int?
    @ObservationIgnored var activeRuntimeMediaURLForCallbacks: URL?
    private var needsMutedMediaStartupAfterClearedProgram = false
    var programItems: [ProgramItem] = []
    var showAgendaTimeline: Bool = false {
        didSet {
            guard oldValue != showAgendaTimeline else { return }
            dispatchRuntimeFacadeAction(.operatorSetShowAgendaTimeline(showAgendaTimeline))
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
        }
    }

    /// 媒体源音量 [0.0, 1.0]
    var mediaVolume: Double = 1.0 {
        didSet {
            guard oldValue != mediaVolume else { return }
            dispatchRuntimeFacadeAction(.operatorChangedMediaVolume(mediaVolume))
        }
    }

    /// BGM 音量 [0.0, 1.0]
    var bgmVolume: Double = 0.5 {
        didSet {
            guard oldValue != bgmVolume else { return }
            dispatchRuntimeFacadeAction(.operatorChangedBGMVolume(bgmVolume))
        }
    }

    /// Live mode mute controls are session-scoped operator actions and are not persisted.
    var isMasterAudioMuted: Bool = false {
        didSet {
            guard oldValue != isMasterAudioMuted else { return }
            dispatchRuntimeFacadeAction(.operatorChangedMasterMute(isMasterAudioMuted))
        }
    }
    var isMediaAudioMuted: Bool = false {
        didSet {
            guard oldValue != isMediaAudioMuted else { return }
            dispatchRuntimeFacadeAction(.operatorChangedMediaMute(isMediaAudioMuted))
        }
    }
    var isBGMAudioMuted: Bool = false {
        didSet {
            guard oldValue != isBGMAudioMuted else { return }
            dispatchRuntimeFacadeAction(.operatorChangedBGMMute(isBGMAudioMuted))
        }
    }

    /// 音频输出策略。默认保持“混合”，与当前已存在的实际行为一致。
    var audioStrategy: AudioStrategy = .mixed {
        didSet {
            guard oldValue != audioStrategy else { return }
            dispatchRuntimeFacadeAction(.operatorSelectedAudioStrategy(audioStrategy))
        }
    }

    // MARK: - 转场配置

    var crossfadeDuration: Double = 3.0
    var liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    let speakerModeDuckedRatio = AudioRoutingDefaults.speakerModeDuckedRatio

    // MARK: - 背景壁纸（多张）

    var backgroundWallpapers: [URL] = []
    var backgroundImage: NSImage?
    var activeWallpaperURL: URL? {
        didSet {
            dispatchRuntimeFacadeAction(.operatorSetActiveWallpaperURL(activeWallpaperURL))
        }
    }
    var cornerLogoURL: URL? {
        didSet {
            dispatchRuntimeFacadeAction(.operatorSetCornerLogoURL(cornerLogoURL))
        }
    }
    var cornerLogoImage: NSImage?
    var cornerLogoPosition: CornerLogoPosition = .topRight {
        didSet {
            guard oldValue != cornerLogoPosition else { return }
            dispatchRuntimeFacadeAction(.operatorSetCornerLogoPosition(cornerLogoPosition))
        }
    }

    // MARK: - BGM 列表

    var bgmItems: [BGMItem] = []
    var currentBGMItem: BGMItem?
    var isBGMPlaying: Bool = false
    @ObservationIgnored var transientRuntimeBGMItem: BGMItem?
    var isBGMAudioTakeoverActive: Bool = false {
        didSet {
            guard oldValue != isBGMAudioTakeoverActive else { return }
            dispatchRuntimeFacadeAction(.operatorChangedBGMTakeover(isBGMAudioTakeoverActive))
        }
    }
    var bgmPlayMode: BGMPlayMode = .loopAll
    var supportEvents: [LiveSupportEvent] = []

    /// V26.3: 主讲人模式（一键压限 BGM）
    var isSpeakerMode: Bool = false {
        didSet {
            guard oldValue != isSpeakerMode else { return }
            dispatchRuntimeFacadeAction(.operatorSetSpeakerMode(isSpeakerMode))
        }
    }

    /// 视频播毕后仅自动播放队列里的紧邻下一条视频；默认关闭，避免现场自动打开演示文件。
    var autoPlayNextVideoOnEnd: Bool = false {
        didSet {
            guard oldValue != autoPlayNextVideoOnEnd else { return }
            dispatchRuntimeFacadeAction(.operatorSetAutoPlayNextVideoOnEnd(autoPlayNextVideoOnEnd))
        }
    }
    var autoAdvanceAtScheduledTime: Bool = false {
        didSet {
            guard oldValue != autoAdvanceAtScheduledTime else { return }
            dispatchRuntimeFacadeAction(.operatorSetAutoAdvanceAtScheduledTime(autoAdvanceAtScheduledTime))
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

    let runtime: LiveRuntimeStore
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
    // MARK: - Combine / Timers

    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored let cleanupBag = ViewModelCleanupBag()
    private var bgmTransitionGeneration: Int = 0
    @ObservationIgnored var activeRuntimeBGMGenerationForCallbacks: Int?
    @ObservationIgnored var activeRuntimeBGMItemIDForCallbacks: UUID?
    @ObservationIgnored var activeRuntimeBGMURLForCallbacks: URL?
    @ObservationIgnored private var activeBGMTimerGeneration: Int?
    @ObservationIgnored private var pendingPPTToggleSource: PPTModeToggleSource?
    private var agendaAutoAdvancePromptedItemIDs = Set<UUID>()

    // MARK: - V25: 翻页拦截器状态
    /// 翻页笔拦截开关（开启时全局拦截 PageUp/Down/左右箭头并转发给 WPS）
    var isPageInterceptEnabled: Bool = false
    @ObservationIgnored var pageInterceptSideEffectsEnabled = true
    @ObservationIgnored var pageInterceptStartOverride: (() -> Bool)?
    @ObservationIgnored var scanOpenKeynoteFilesForTesting: (() -> [String])?
    @ObservationIgnored var scanKeynoteWindowNamesForTesting: (() throws -> [String])?
    @ObservationIgnored var automationCommandRunnerForTesting: ((String, String) throws -> Void)?
    @ObservationIgnored var automationCommandDidFinishForTesting: (() -> Void)?
    @ObservationIgnored var saveDataDidRun: (() -> Void)?

    func togglePPTMode(source: PPTModeToggleSource = .programmatic) {
        dispatchPPTIntent(.operatorToggledPPTMode(source: source), source: source)
    }

    func setPPTMode(_ enabled: Bool, source: PPTModeToggleSource = .programmatic) {
        dispatchPPTIntent(.operatorSetPPTMode(enabled, source: source), source: source)
    }

    var pageInterceptEventTap: CFMachPort?
    private var pageInterceptRunLoopSource: CFRunLoopSource?
    private var pageInterceptSelfRefcon: UnsafeMutableRawPointer?
    nonisolated private let pageInterceptRuntime = PageInterceptRuntime()
    nonisolated private let wpsApplicationMonitor = WPSApplicationMonitor()

    // MARK: - V21 Fix #1: BGM Delegate（持有 delegate 防止 ARC 释放）
    let bgmDelegate = BGMPlayerDelegate()
    let userDefaults: UserDefaults

    // MARK: - UserDefaults Keys

    enum UDKeys {
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
        userDefaults: UserDefaults = .standard,
        runtime: LiveRuntimeStore? = nil
    ) {
        let runtimePorts = SwitcherRuntimePortBundle()
        self.userDefaults = userDefaults
        self.runtime = runtime ?? LiveRuntimeStore(
            effectRunner: runtimePorts.makeEffectRunner(),
            environment: .productionAutomationCommandOwning()
        )
        configureRuntimePortHandlers(runtimePorts)
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

    private func dispatchPPTIntent(_ action: LiveRuntimeAction, source: PPTModeToggleSource) {
        let previousPPT = runtime.state.ppt
        pendingPPTToggleSource = source
        dispatchRuntimeFacadeAction(action)
        syncPPTFacadeFromRuntime()
        if runtime.state.ppt == previousPPT {
            pendingPPTToggleSource = nil
        }
    }

    // MARK: - 音量实际应用（Fix Issue #7/#8）

    func applyMasterVolume() {
        applyCurrentRuntimeAudioRouting(reason: .operatorFaderChanged)
    }

    func applyBGMVolume() {
        applyCurrentRuntimeAudioRouting(reason: .operatorFaderChanged)
    }

    func effectiveMediaOutputVolume() -> Float {
        runtime.state.audio.effectiveMedia
    }

    func effectiveBGMOutputVolume() -> Float {
        runtime.state.audio.effectiveBGM
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

    private var legacyAudioRoutingOutputForSnapshotOnly: AudioRoutingOutput {
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

    func applyAudioRouting(
        mediaFadeDuration: Double? = nil,
        bgmFadeDuration: Double? = nil,
        effectiveMedia: Float? = nil,
        effectiveBGM: Float? = nil
    ) {
        let effectiveMedia = effectiveMedia ?? effectiveMediaOutputVolume()
        if let mediaFadeDuration {
            fadeMediaVolume(to: effectiveMedia, duration: mediaFadeDuration)
        } else {
            cleanupBag.mediaVolumeFadeTask?.cancel()
            avCoordinator.volume = effectiveMedia
        }

        let effectiveBGM = effectiveBGM ?? appliedBGMOutputVolume()
        let bgmGeneration = runtime.state.bgm.currentID == nil ? nil : runtime.state.bgm.generation
        if let bgmFadeDuration, let bgmGeneration, bgmAudioPlayer != nil {
            fadeCurrentBGMPlayerVolume(to: effectiveBGM, duration: bgmFadeDuration, generation: bgmGeneration)
        } else {
            cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
            bgmAudioPlayer?.volume = effectiveBGM
        }

        if let bgmFadeDuration, let bgmGeneration {
            fadeCurrentBGMFallbackVolume(to: effectiveBGM, duration: bgmFadeDuration, generation: bgmGeneration)
        } else {
            cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
            bgmFallbackPlayer.volume = effectiveBGM
        }
    }

    private func appliedBGMOutputVolume(sourceState: LiveRuntimeState? = nil) -> Float {
        let state = sourceState ?? runtime.state
        return state.bgm.isPlaying ? state.audio.effectiveBGM : 0
    }

    func applyAudioRoutingForRuntimeChange(
        reason: AudioRoutingRuntimeChangeReason,
        runtimeState: LiveRuntimeState
    ) {
        let transition = AudioRoutingTransitionPolicy.transition(
            for: reason,
            liveAudioFadeDuration: liveAudioFadeDuration
        )
        lastAudioRoutingTransition = transition
        applyAudioRouting(
            mediaFadeDuration: transition.mediaFadeDuration,
            bgmFadeDuration: transition.bgmFadeDuration,
            effectiveMedia: runtimeState.audio.effectiveMedia,
            effectiveBGM: appliedBGMOutputVolume(sourceState: runtimeState)
        )
    }

    func applyCurrentRuntimeAudioRouting(reason: AudioRoutingRuntimeChangeReason) {
        syncRuntimeAudioInputsFromFacade(reason: reason)
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

    var activeBGMTimerGenerationForTesting: Int? {
        activeBGMTimerGeneration
    }

    var activeRuntimeBGMCallbackGenerationForTesting: Int? {
        activeRuntimeBGMGenerationForCallbacks
    }

    var activeRuntimeBGMCallbackItemIDForTesting: UUID? {
        activeRuntimeBGMItemIDForCallbacks
    }

    var activeRuntimeBGMCallbackURLForTesting: URL? {
        activeRuntimeBGMURLForCallbacks
    }

    func seedActiveRuntimeBGMCallbackForTesting(item: BGMItem, generation: Int) {
        activeRuntimeBGMGenerationForCallbacks = generation
        activeRuntimeBGMItemIDForCallbacks = item.id
        activeRuntimeBGMURLForCallbacks = item.url
    }

    func invalidateBGMTransitionGeneration() {
        bgmTransitionGeneration += 1
    }

    func fadeMediaVolume(to targetVolume: Float, duration: Double) {
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

    private func fadeCurrentBGMFallbackVolume(to targetVolume: Float, duration: Double, generation: Int) {
        cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
        guard duration > 0 else {
            guard runtime.state.bgm.generation == generation else { return }
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
                guard self?.runtime.state.bgm.generation == generation else { return }
                self?.bgmFallbackPlayer.volume = volume
            }
        }
    }

    private func fadeCurrentBGMPlayerVolume(to targetVolume: Float, duration: Double, generation: Int) {
        cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
        guard let player = bgmAudioPlayer else { return }
        guard duration > 0 else {
            guard runtime.state.bgm.generation == generation else { return }
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
                guard self.runtime.state.bgm.generation == generation else { return }
                player?.volume = volume
            }
        }
    }

    func prepareRuntimeBGM(_ item: BGMItem, generation: Int) {
        activeRuntimeBGMGenerationForCallbacks = generation
        activeRuntimeBGMItemIDForCallbacks = item.id
        activeRuntimeBGMURLForCallbacks = item.url
        bgmTransitionGeneration = generation
        let fadeDuration = liveAudioFadeDuration

        cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
        cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
        if let oldPlayer = bgmAudioPlayer {
            fadeRetiredBGMPlayerVolume(oldPlayer, to: 0, duration: fadeDuration)
            releaseRetiredBGMPlayerAfterFade(oldPlayer, duration: fadeDuration)
        }
        bgmAudioPlayer?.delegate = nil
        bgmAudioPlayer = nil
        resetBGMRealtimeMeter()
        removeBGMFallbackEndObserver()
        retireCurrentBGMFallbackPlayerForSwitch(duration: fadeDuration)

        if let player = try? AVAudioPlayer(contentsOf: item.url) {
            player.volume = 0
            player.numberOfLoops = BGMPlaybackEndPolicy.numberOfLoops(for: runtime.state.bgm.playMode)
            player.delegate = bgmDelegate
            player.isMeteringEnabled = true
            player.prepareToPlay()
            bgmAudioPlayer = player
        } else {
            let avItem = AVPlayerItem(url: item.url)
            installBGMFallbackEndObserver(for: avItem)
            bgmFallbackPlayer.replaceCurrentItem(with: avItem)
            bgmFallbackPlayer.volume = 0
            resetBGMRealtimeMeter()
        }
    }

    func playRuntimeBGM(generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        activeRuntimeBGMGenerationForCallbacks = generation
        bgmTransitionGeneration = generation
        rewindBGMIfAtEndBeforeResume()
        bgmAudioPlayer?.volume = 0
        bgmAudioPlayer?.isMeteringEnabled = true
        bgmAudioPlayer?.play()
        bgmFallbackPlayer.volume = 0
        bgmFallbackPlayer.play()
        let targetVolume = runtime.state.audio.effectiveBGM
        fadeCurrentBGMPlayerVolume(to: targetVolume, duration: liveAudioFadeDuration, generation: generation)
        fadeCurrentBGMFallbackVolume(to: targetVolume, duration: liveAudioFadeDuration, generation: generation)
    }

    func pauseRuntimeBGM(generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        bgmAudioPlayer?.pause()
        bgmFallbackPlayer.pause()
    }

    func stopRuntimeBGM(fade: TimeInterval, generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        activeRuntimeBGMGenerationForCallbacks = nil
        activeRuntimeBGMItemIDForCallbacks = nil
        activeRuntimeBGMURLForCallbacks = nil
        bgmTransitionGeneration = generation
        resetBGMRealtimeMeter()
        clearBGMTakeoverIfNeeded()
        cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
        cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
        if let player = bgmAudioPlayer {
            player.delegate = nil
            if fade > 0 {
                fadeRetiredBGMPlayerVolume(player, to: 0, duration: fade)
                releaseRetiredBGMPlayerAfterFade(player, duration: fade)
            } else {
                player.stop()
                player.volume = 0
                player.currentTime = 0
            }
        }
        bgmAudioPlayer = nil
        if fade > 0 {
            fadeCurrentBGMFallbackVolume(to: 0, duration: fade, generation: generation)
            releaseBGMFallbackAfterFade(duration: fade, generation: generation)
        } else {
            removeBGMFallbackEndObserver()
            bgmFallbackPlayer.pause()
            bgmFallbackPlayer.volume = 0
            bgmFallbackPlayer.replaceCurrentItem(with: nil)
        }
    }

    func setRuntimeBGMVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        if bgmAudioPlayer != nil {
            fadeCurrentBGMPlayerVolume(to: volume, duration: fade, generation: generation)
        } else {
            cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
            bgmAudioPlayer?.volume = volume
        }
        fadeCurrentBGMFallbackVolume(to: volume, duration: fade, generation: generation)
    }

    func seekRuntimeBGMToBeginning(generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        bgmAudioPlayer?.currentTime = 0
        bgmFallbackPlayer.seek(to: .zero)
        bgmProgressStore.update(currentTime: 0, duration: bgmAudioPlayer?.duration ?? fallbackBGMKnownDuration() ?? 0)
    }

    func seekRuntimeBGM(toProgress progress: Double, generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
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

    func setRuntimeBGMPlayMode(_ playMode: BGMPlayMode, generation: Int?) {
        if let generation {
            guard runtime.state.bgm.generation == generation else { return }
        }
        bgmAudioPlayer?.numberOfLoops = BGMPlaybackEndPolicy.numberOfLoops(for: playMode)
    }

    private func fadeRetiredBGMPlayerVolume(_ player: AVAudioPlayer, to targetVolume: Float, duration: Double) {
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

    var currentProgramIsMediaSource: Bool {
        currentProgramItem?.sourceKind == .media
    }

    func loadBackgroundImage(from url: URL?) {
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

    func loadCornerLogoImage(from url: URL?) {
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
        let isAvailable = externalScreenProvider() != nil
        guard isAvailable != isExternalDisplayAvailable else { return }

        isExternalDisplayAvailable = isAvailable
        if isAvailable {
            dispatchRuntimeFacadeAction(.projectionExternalDisplayAvailable)
        } else {
            dispatchRuntimeFacadeAction(.projectionExternalDisplayUnavailable)
        }
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
        userDefaults.set(audioStrategy.rawValue, forKey: UDKeys.audioStrategy)
        userDefaults.set(isSpeakerMode, forKey: UDKeys.speakerMode)
        userDefaults.set(bgmPlayMode.rawValue, forKey: UDKeys.bgmPlayMode)

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
        saveDataDidRun?()
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

        switch item.sourceKind {
        case .agendaMarker, .unsupported:
            return
        case .media:
            stopCurrentDeckPresentationIfNeeded(before: item)
            dispatchRuntimeProgramSelection(for: item)
            currentHTMLURL = nil              // 清空 HTML 层
            needsMutedMediaStartupAfterClearedProgram = false
            setCurrentProgramFromOperatorSelection(item)
        case .keynote:
            guard let url = item.sourceURL else { return }
            if !isLikelyValidDeckDocument(url: url, sourceKind: .keynote) {
                invalidDeckHandler(url)
                return
            }
            stopCurrentDeckPresentationIfNeeded(before: item)
            dispatchRuntimeProgramSelection(for: item)
            setCurrentProgramFromOperatorSelection(item)
            currentHTMLURL = nil              // 清空 HTML 层
            keynotePresentationHandler(url)
        case .pptx:
            guard let url = item.sourceURL else { return }
            if !isLikelyValidDeckDocument(url: url, sourceKind: .pptx) {
                invalidDeckHandler(url)
                return
            }
            stopCurrentDeckPresentationIfNeeded(before: item)
            dispatchRuntimeProgramSelection(for: item)
            setCurrentProgramFromOperatorSelection(item)
            currentHTMLURL = nil              // 清空 HTML 层
            pptxOpenHandler(url)
        case .html:
            guard let url = item.sourceURL else { return }
            stopCurrentDeckPresentationIfNeeded(before: item)
            dispatchRuntimeProgramSelection(for: item)
            setCurrentProgramFromOperatorSelection(item)
            openHTMLInOutputWindow(url: url)
        case .activeDeck:
            stopCurrentDeckPresentationIfNeeded(before: item)
            dispatchRuntimeProgramSelection(for: item)
            setCurrentProgramFromOperatorSelection(item)
            currentHTMLURL = nil
            activeDeckPresentationHandler()
        }
    }

    private func setCurrentProgramFromOperatorSelection(_ item: ProgramItem?) {
        suppressCurrentProgramFacadeDispatch = true
        defer { suppressCurrentProgramFacadeDispatch = false }
        currentProgramItem = item
    }

    private func dispatchRuntimeProgramSelection(for item: ProgramItem) {
        if programItems.contains(where: { $0.id == item.id }) {
            dispatchRuntimeFacadeAction(.operatorSelectedProgram(item.id))
        } else {
            dispatchRuntimeFacadeAction(.operatorSelectedDetachedProgram(item))
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
        dispatchRuntimeFacadeAction(.automationScriptRequested(script: source, action: action))
    }

    func handleAppleScriptFailure(_ error: Error, action: String) {
        let sanitizedMessage = sanitizedAutomationFailureMessage(error)
        let supportMessage = AutomationFailureSanitizer.sanitizedSupportMessage(from: error)
        recordSupportEvent(kind: .appleScriptFailed, detail: "action=\(action),error=\(supportMessage)")
        dispatchRuntimeFacadeAction(.automationFailed(action: action, sanitizedMessage: sanitizedMessage))
        syncSupportFacadeFromRuntime()
        syncAutomationNoticeFacadeFromRuntime()
    }

    func dismissAutomationRuntimeNotice() {
        cancelAutomationNoticeExpiryTask()
        dispatchRuntimeFacadeAction(.automationNoticeDismissed)
        syncAutomationNoticeFacadeFromRuntime()
    }

    func expireAutomationRuntimeNotice(id: UUID, now: Date = Date()) {
        guard let notice = automationRuntimeNotice,
              notice.id == id,
              let expiresAt = notice.expiresAt,
              now >= expiresAt
        else { return }
        cancelAutomationNoticeExpiryTask()
        dispatchRuntimeFacadeAction(.automationNoticeExpired(id))
        syncAutomationNoticeFacadeFromRuntime()
    }

    private func showAutomationRuntimeNotice(action: String) {
        dispatchRuntimeFacadeAction(.automationNoticeRequested(action: action))
        syncAutomationNoticeFacadeFromRuntime()
    }

    func cancelAutomationNoticeExpiryTask() {
        cleanupBag.automationNoticeExpiryTask?.cancel()
        cleanupBag.automationNoticeExpiryTask = nil
        cleanupBag.automationNoticeExpiryTaskNoticeID = nil
    }

    func expireAutomationNoticeFromScheduledTask(id: UUID) {
        guard runtime.state.automation.notice?.id == id else { return }
        dispatchRuntimeFacadeAction(.automationNoticeExpired(id))
        syncAutomationNoticeFacadeFromRuntime()
    }

    var automationNoticeExpiryTaskIsActiveForTesting: Bool {
        guard let task = cleanupBag.automationNoticeExpiryTask else { return false }
        return !task.isCancelled
    }

    var automationNoticeExpiryTaskNoticeIDForTesting: UUID? {
        cleanupBag.automationNoticeExpiryTaskNoticeID
    }

    func expireAutomationNoticeFromScheduledTaskForTesting(id: UUID) {
        expireAutomationNoticeFromScheduledTask(id: id)
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

    private func sanitizedAutomationFailureMessage(_ error: Error) -> String {
        AutomationFailureSanitizer.sanitizedMessage(from: error)
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

    private func scanKeynoteWindowNames() throws -> [String] {
        if let scanKeynoteWindowNamesForTesting {
            return try scanKeynoteWindowNamesForTesting()
        }

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
            throw error
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
        return windowNames
    }

    private func scanOpenKeynoteFiles() -> [String] {
        if let scanOpenKeynoteFilesForTesting {
            return scanOpenKeynoteFilesForTesting()
        }
        return keynoteController.scanOpenKeynoteFiles()
    }

    func scanAndAddKeynoteWindows() {
        let windowNames: [String]
        do {
            windowNames = try scanKeynoteWindowNames()
        } catch {
            return
        }

        let docPaths = scanOpenKeynoteFiles()
        var itemsToAdd: [ProgramItem] = []

        if !docPaths.isEmpty {
            for path in docPaths {
                let url = URL(fileURLWithPath: path)
                let alreadyAdded = programItems.contains { $0.sourceURL == url }
                    || itemsToAdd.contains { $0.sourceURL == url }
                if !alreadyAdded {
                    let item = ProgramItem(
                        title: url.deletingPathExtension().lastPathComponent,
                        subtitle: "KEY",
                        sourceURL: url
                    )
                    itemsToAdd.append(item)
                }
            }
        } else if !windowNames.isEmpty {
            for name in windowNames {
                let cleanName = KeynoteController.cleanedDocumentTitle(from: name)
                let alreadyAdded = programItems.contains { $0.title == cleanName }
                    || itemsToAdd.contains { $0.title == cleanName }
                if !alreadyAdded {
                    let item = ProgramItem(
                        title: cleanName,
                        subtitle: "KEY (活动)",
                        sourceURL: nil
                    )
                    itemsToAdd.append(item)
                }
            }
        }
        addProgramItems(itemsToAdd)
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
            if runtime.state.media.isPlaying || avCoordinator.isPlaying {
                dispatchRuntimeFacadeAction(.operatorPausedMediaForPanic(generation: nil))
                if panicPlaybackSnapshot?.currentProgramID == item.id {
                    panicPlaybackSnapshot?.wasMediaPlaying = false
                }
            }
            return
        }

        // 普通视频
        dispatchRuntimeFacadeAction(.operatorToggledMediaPlayback)
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
            dispatchRuntimeFacadeAction(.operatorSeekedCurrentMediaToStart)
        }
    }

    func restartCurrentMediaFromBeginning() {
        guard let item = currentProgramItem,
              programItemSupportsSeeking(item) else { return }
        dispatchRuntimeFacadeAction(.operatorRestartedCurrentMedia)
        recordSupportEvent(kind: .mediaRestarted, detail: "source=current")
    }

    func seekProgramItemToEnd(_ item: ProgramItem) {
        if currentProgramItem?.id == item.id && programItemSupportsSeeking(item) {
            dispatchRuntimeFacadeAction(.operatorSeekedCurrentMediaToEnd)
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
            if currentProgramItem?.sourceKind == .media {
                dispatchRuntimeFacadeAction(.operatorStoppedCurrentMedia)
            }
            currentProgramItem = nil
            currentHTMLURL = nil   // Bug2修复：删除HTML条目时清空大屏
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
            recordBGMPlaybackState(isPlaying: false, reason: "removed")
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
        dispatchRuntimeFacadeAction(.operatorSeekedBGMToBeginning)
    }

    func seekBGM(toProgress progress: Double) {
        dispatchRuntimeFacadeAction(.operatorSeekedBGMToProgress(progress))
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

        if currentBGMItem?.id == item.id, isBGMPlaying {
            dispatchRuntimeFacadeAction(.operatorStoppedBGM)
            recordBGMPlaybackState(isPlaying: false, reason: "operator")
        } else {
            dispatchRuntimeBGMItemAction(.operatorSelectedBGM(item.id), item: item)
            recordBGMPlaybackState(isPlaying: true, reason: "selected")
        }
    }

    private func cueBGMDuringPanic(_ item: BGMItem) {
        dispatchRuntimeBGMItemAction(.operatorSelectedBGM(item.id), item: item)
        if panicPlaybackSnapshot?.currentBGMID == item.id {
            panicPlaybackSnapshot?.wasBGMPlaying = false
        }
        recordBGMPlaybackState(isPlaying: false, reason: "cuedDuringPanic")
    }

    private func dispatchRuntimeBGMItemAction(_ action: LiveRuntimeAction, item: BGMItem) {
        transientRuntimeBGMItem = item
        defer { transientRuntimeBGMItem = nil }
        dispatchRuntimeFacadeAction(action)
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

    private func startBGMTimer() {
        startBGMTimer(generation: bgmTransitionGeneration)
    }

    func startBGMTimer(generation: Int) {
        stopActiveBGMTimer()
        bgmTransitionGeneration = generation
        activeBGMTimerGeneration = generation
        cleanupBag.bgmProgressTimer = Timer.scheduledTimer(withTimeInterval: BGMProgressStore.updateInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.activeBGMTimerGeneration == generation else { return }
                self.updateBGMProgress(generation: generation)
            }
        }
    }

    private func stopBGMTimer() {
        stopActiveBGMTimer()
    }

    private func stopActiveBGMTimer() {
        cleanupBag.bgmProgressTimer?.invalidate()
        cleanupBag.bgmProgressTimer = nil
        activeBGMTimerGeneration = nil
    }

    func stopBGMTimer(generation: Int) {
        guard activeBGMTimerGeneration == generation else { return }
        stopActiveBGMTimer()
    }

    private func releaseRetiredBGMPlayerAfterFade(_ player: AVAudioPlayer, duration: Double) {
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
            guard !self.isBGMPlaying else { return }
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

    private func updateBGMProgress(generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        if let player = bgmAudioPlayer {
            let currentTime = player.currentTime
            let duration = player.duration
            runtime.dispatch(.bgmProgressUpdated(time: currentTime, duration: duration, generation: generation))
            syncBGMFacadeFromRuntime()
            updateBGMRealtimeMeter(from: player)
            finishBGMIfProgressReachedEnd(currentTime: currentTime, duration: duration)
        } else if isBGMPlaying {
            let fallbackTime = bgmFallbackPlayer.currentTime().seconds
            let itemDuration = bgmFallbackPlayer.currentItem?.duration.seconds
            let fallbackDuration = bgmDuration ?? ((itemDuration ?? 0) > 0 && itemDuration?.isFinite == true ? itemDuration : nil)
            if fallbackTime.isFinite, let fallbackDuration, fallbackDuration > 0 {
                runtime.dispatch(.bgmProgressUpdated(time: fallbackTime, duration: fallbackDuration, generation: generation))
                syncBGMFacadeFromRuntime()
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
        refreshExternalDisplayAvailability()
        let oldProjection = runtime.state.projection
        dispatchRuntimeFacadeAction(.operatorToggledProjection)
        syncProjectionFacadeFromRuntime()
        recordProjectionSupportAfterRuntimeToggle(old: oldProjection, new: runtime.state.projection)
        if oldProjection.isBroadcasting != runtime.state.projection.isBroadcasting {
            LiveSwitcherTelemetry.projectionToggle(isBroadcasting: isBroadcasting)
        }
    }

    func showOutputWindowFromRuntimeProjection() {
        guard let targetScreen = projectionService.targetScreen() else {
            let oldProjection = runtime.state.projection
            dispatchRuntimeFacadeAction(.projectionStartFailed(reason: .noTargetScreen))
            syncProjectionFacadeFromRuntime()
            recordProjectionSupportAfterRuntimeStartFailure(
                old: oldProjection,
                new: runtime.state.projection,
                reason: .noTargetScreen
            )
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
        outputWindowController?.show(on: targetScreen)
    }

    func hideOutputWindowFromRuntimeProjection() {
        outputWindowController?.hide()
    }

    func handleExternalDisplayLost() {
        guard runtime.state.projection.isBroadcasting else { return }
        let oldProjection = runtime.state.projection
        dispatchRuntimeFacadeAction(.projectionExternalDisplayLost)
        syncProjectionFacadeFromRuntime()
        recordProjectionSupportAfterRuntimeDisplayLost(old: oldProjection, new: runtime.state.projection)
    }

    private func recordProjectionSupportAfterRuntimeToggle(
        old: ProjectionRuntimeState,
        new: ProjectionRuntimeState
    ) {
        if !old.isBroadcasting, new.isBroadcasting {
            recordSupportEvent(kind: .projectionStarted, detail: "isBroadcasting=true")
            recordSupportEvent(kind: .projectionToggle, detail: "isBroadcasting=true")
        } else if old.isBroadcasting, !new.isBroadcasting {
            recordSupportEvent(kind: .projectionStopped, detail: "isBroadcasting=false")
            recordSupportEvent(kind: .projectionToggle, detail: "isBroadcasting=false")
        } else if !old.isBroadcasting,
                  !new.isBroadcasting,
                  new.safetyNotice == "未检测到外接屏幕，未开始投射" {
            LiveSwitcherTelemetry.projectionFailClosed()
            recordSupportEvent(kind: .projectionFailClosed, detail: "externalDisplay=false")
            recordSupportEvent(kind: .projectionStartFailed, detail: "externalDisplay=false")
        }
    }

    private func recordProjectionSupportAfterRuntimeStartFailure(
        old: ProjectionRuntimeState,
        new: ProjectionRuntimeState,
        reason: ProjectionStartFailureReason
    ) {
        guard !old.isBroadcasting,
              !new.isBroadcasting,
              new.safetyNotice == "未检测到外接屏幕，未开始投射"
        else { return }

        LiveSwitcherTelemetry.projectionFailClosed()
        recordSupportEvent(kind: .projectionFailClosed, detail: "reason=\(reason.rawValue)")
        recordSupportEvent(kind: .projectionStartFailed, detail: "reason=\(reason.rawValue)")
    }

    private func recordProjectionSupportAfterRuntimeDisplayLost(
        old: ProjectionRuntimeState,
        new: ProjectionRuntimeState
    ) {
        guard old.isBroadcasting, !new.isBroadcasting else { return }

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
        dispatchRuntimeFacadeAction(.supportEventRecorded(event))
        syncSupportFacadeFromRuntime()
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

    func startPPTEventTapFromRuntime() {
        if let pageInterceptStartOverride {
            if pageInterceptStartOverride() {
                completePPTEventTapStartFromRuntime(detail: "state=enabled,override=true")
                return
            }
            completePPTEventTapStartFailureFromRuntime(reason: "overrideFailed", presentAlert: false)
            return
        }

        guard pageInterceptSideEffectsEnabled else {
            completePPTEventTapStartFromRuntime(detail: "state=enabled,sideEffects=false")
            return
        }

        _ = startPageIntercept()
    }

    func stopPPTEventTapFromRuntime(reason: PPTStopReason) {
        guard pageInterceptSideEffectsEnabled else {
            completePPTEventTapStopFromRuntime(reason: reason, detail: "state=disabled,reason=\(reason.rawValue),sideEffects=false")
            return
        }
        stopPageIntercept(reason: reason)
    }

    private func completePPTEventTapStartFromRuntime(detail: String) {
        let oldPPT = runtime.state.ppt
        dispatchRuntimeFacadeAction(.pptEventTapStarted)
        syncPPTFacadeFromRuntime()
        guard !oldPPT.isEventTapActive, runtime.state.ppt.isEventTapActive else { return }
        LiveSwitcherTelemetry.pageInterceptEnabled()
        recordSupportEvent(kind: .pageInterceptEnabled, detail: detail)
        if let source = pendingPPTToggleSource {
            recordSupportEvent(
                kind: .pptModeChanged,
                detail: "isOn=true,source=\(source.rawValue)"
            )
        }
        pendingPPTToggleSource = nil
    }

    private func completePPTEventTapStartFailureFromRuntime(reason: String, presentAlert: Bool) {
        let oldPPT = runtime.state.ppt
        dispatchRuntimeFacadeAction(.pptEventTapFailed(reason: reason))
        syncPPTFacadeFromRuntime()
        guard oldPPT.isRequested || oldPPT.isEventTapActive || pendingPPTToggleSource != nil else { return }
        LiveSwitcherTelemetry.pageInterceptDisabled(reason: reason)
        recordSupportEvent(kind: .pageInterceptDisabled, detail: "reason=\(reason)")
        pendingPPTToggleSource = nil
        guard presentAlert else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.presentAutomationAlert(
                title: "PPT模式无法启动",
                message: "翻页笔接管需要「辅助功能」权限。\n\n请前往：系统设置 → 隐私与安全性 → 辅助功能，找到\"LiveSwitcher\"并打开开关。\n\n设置完成后，重新启动 App 再开启 PPT模式。",
                action: "pageIntercept.\(reason)",
                primaryButton: "打开系统设置",
                secondaryButton: "稍后处理"
            ) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func completePPTEventTapStopFromRuntime(reason: PPTStopReason, detail: String? = nil) {
        let oldPPT = runtime.state.ppt
        dispatchRuntimeFacadeAction(.pptEventTapStopped(reason: reason))
        syncPPTFacadeFromRuntime()
        guard oldPPT.isRequested || oldPPT.isEventTapActive || pendingPPTToggleSource != nil else { return }
        LiveSwitcherTelemetry.pageInterceptDisabled(reason: reason.rawValue)
        recordSupportEvent(kind: .pageInterceptDisabled, detail: detail ?? "state=disabled,reason=\(reason.rawValue)")
        if let source = pendingPPTToggleSource {
            recordSupportEvent(
                kind: .pptModeChanged,
                detail: "isOn=false,source=\(source.rawValue)"
            )
        }
        pendingPPTToggleSource = nil
    }

    private func startPageIntercept() -> Bool {
        // 权限预检查：无辅助功能权限时提前提示，避免 tapCreate 静默失败
        let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        if !AXIsProcessTrustedWithOptions(axOptions) {
            completePPTEventTapStartFailureFromRuntime(reason: "accessibilityPermission", presentAlert: false)
            Task { @MainActor [weak self] in
                guard let self else { return }
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
            return false
        }

        guard pageInterceptEventTap == nil else {
            // 已有 tap，直接 enable
            if let tap = pageInterceptEventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                pageInterceptRuntime.updateEventTap(tap)
                completePPTEventTapStartFromRuntime(detail: "state=enabled,existingTap=true")
            }
            return true
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
            completePPTEventTapStartFailureFromRuntime(reason: "eventTapCreateFailed", presentAlert: true)
            return false
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        pageInterceptEventTap = tap
        pageInterceptRunLoopSource = src
        pageInterceptSelfRefcon = selfRefcon
        pageInterceptRuntime.updateEventTap(tap)
        completePPTEventTapStartFromRuntime(detail: "state=enabled")
        return true
    }

    private func stopPageIntercept(reason: PPTStopReason = .operatorDisabled) {
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
        completePPTEventTapStopFromRuntime(reason: reason)
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
