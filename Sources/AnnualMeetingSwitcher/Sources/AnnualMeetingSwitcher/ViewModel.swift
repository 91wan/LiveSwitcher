import SwiftUI
import Observation
import Combine
import AppKit
import AVFoundation
import Carbon         // V25: 翻页拦截器 CGEventTap
import ApplicationServices // V25: AXIsProcessTrusted

// MARK: - 导播台核心 ViewModel

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
    @ObservationIgnored var suppressCurrentProgramFacadeDispatch = false
    @ObservationIgnored private var activeRuntimeMediaGenerationForCallbacks: Int?
    @ObservationIgnored private var activeRuntimeMediaURLForCallbacks: URL?
    var needsMutedMediaStartupAfterClearedProgram = false
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
    private let speakerModeDuckedRatio = AudioRoutingDefaults.speakerModeDuckedRatio

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
    @ObservationIgnored private var transientRuntimeBGMItem: BGMItem?
    var isBGMAudioTakeoverActive: Bool = false {
        didSet {
            guard oldValue != isBGMAudioTakeoverActive else { return }
            dispatchRuntimeFacadeAction(.operatorChangedBGMTakeover(isBGMAudioTakeoverActive))
        }
    }
    var bgmPlayMode: BGMPlayMode = .loopAll
    private(set) var supportEvents: [LiveSupportEvent] = []

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
    var lastAudioRoutingTransition: AudioRoutingTransition?

    // MARK: - 引擎

    let runtime: LiveRuntimeStore
    let keynoteController = KeynoteController()
    let avCoordinator = AVPlayerCoordinator()

    // MARK: - 推流窗口

    var outputWindowController: OutputWindowControlling?
    var externalScreenProvider: () -> NSScreen? = {
        SecondScreenSelector.pickExternal()
    } {
        didSet {
            refreshExternalDisplayAvailability()
        }
    }
    var isExternalDisplayAvailable: Bool = false
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
    var isPresentingAutomationAlert = false
    let automationAlertSuppressionWindow: TimeInterval = 15
    var automationAlertSuppressionUntilByAction: [String: Date] = [:]
    // MARK: - Combine / Timers

    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored let cleanupBag = ViewModelCleanupBag()
    var bgmTransitionGeneration: Int = 0
    @ObservationIgnored private var activeRuntimeBGMGenerationForCallbacks: Int?
    @ObservationIgnored private var activeRuntimeBGMItemIDForCallbacks: UUID?
    @ObservationIgnored private var activeRuntimeBGMURLForCallbacks: URL?
    @ObservationIgnored var activeBGMTimerGeneration: Int?
    @ObservationIgnored var pendingPPTToggleSource: PPTModeToggleSource?
    var agendaAutoAdvancePromptedItemIDs = Set<UUID>()

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
    var pageInterceptRunLoopSource: CFRunLoopSource?
    var pageInterceptSelfRefcon: UnsafeMutableRawPointer?
    nonisolated let pageInterceptRuntime = PageInterceptRuntime()
    nonisolated let wpsApplicationMonitor = WPSApplicationMonitor()

    // MARK: - V21 Fix #1: BGM Delegate（持有 delegate 防止 ARC 释放）
    let bgmDelegate = BGMPlayerDelegate()
    private let userDefaults: UserDefaults

    var persistenceFacadeUserDefaults: UserDefaults {
        userDefaults
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

    var runtimeSpeakerModeDuckedRatio: Float {
        speakerModeDuckedRatio
    }

    func applySupportEventsProjectionFromRuntime(_ events: [LiveSupportEvent]) {
        supportEvents = events
    }

    func setActiveRuntimeMediaCallbackIdentity(generation: Int, url: URL) {
        activeRuntimeMediaGenerationForCallbacks = generation
        activeRuntimeMediaURLForCallbacks = url
    }

    func clearActiveRuntimeMediaCallbackIdentity(ifGeneration generation: Int) {
        guard activeRuntimeMediaGenerationForCallbacks == generation else { return }

        activeRuntimeMediaGenerationForCallbacks = nil
        activeRuntimeMediaURLForCallbacks = nil
    }

    func validatedRuntimeMediaCallbackGeneration() -> Int? {
        guard let generation = activeRuntimeMediaGenerationForCallbacks else { return nil }
        guard currentProgramItem?.sourceKind == .media else { return nil }
        guard avCoordinator.currentURL == activeRuntimeMediaURLForCallbacks else { return nil }
        return generation
    }

    func setActiveRuntimeBGMCallbackIdentity(item: BGMItem, generation: Int) {
        activeRuntimeBGMGenerationForCallbacks = generation
        activeRuntimeBGMItemIDForCallbacks = item.id
        activeRuntimeBGMURLForCallbacks = item.url
    }

    func clearActiveRuntimeBGMCallbackIdentity() {
        activeRuntimeBGMGenerationForCallbacks = nil
        activeRuntimeBGMItemIDForCallbacks = nil
        activeRuntimeBGMURLForCallbacks = nil
    }

    func validatedRuntimeBGMCallbackGeneration() -> Int? {
        guard let generation = activeRuntimeBGMGenerationForCallbacks else { return nil }
        guard currentBGMItem?.id == activeRuntimeBGMItemIDForCallbacks else { return nil }
        guard currentBGMItem?.url == activeRuntimeBGMURLForCallbacks else { return nil }
        return generation
    }

    func includeTransientRuntimeBGMItem(_ item: BGMItem) {
        transientRuntimeBGMItem = item
    }

    func clearTransientRuntimeBGMItemIfNeeded(_ item: BGMItem) {
        guard transientRuntimeBGMItem?.id == item.id else { return }
        transientRuntimeBGMItem = nil
    }

    func runtimeBGMItemsForSnapshot() -> [BGMItem] {
        var items = bgmItems
        if runtime.bridgeMode.owns(.bgm),
           let currentRuntimeItem = runtime.state.bgm.currentItem,
           !items.contains(where: { $0.id == currentRuntimeItem.id }) {
            items.append(currentRuntimeItem)
        }
        if let transientRuntimeBGMItem,
           !items.contains(where: { $0.id == transientRuntimeBGMItem.id }) {
            items.append(transientRuntimeBGMItem)
        }
        return items
    }

    var isPageInterceptEventTapActiveForRuntimeSnapshot: Bool {
        pageInterceptEventTap != nil
    }

    func resetLastAudioRoutingTransitionForTesting() {
        lastAudioRoutingTransition = nil
    }

    var activeRuntimeMediaCallbackGenerationForTesting: Int? {
        activeRuntimeMediaGenerationForCallbacks
    }

    var activeRuntimeMediaCallbackURLForTesting: URL? {
        activeRuntimeMediaURLForCallbacks
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
        setActiveRuntimeBGMCallbackIdentity(item: item, generation: generation)
    }

    func invalidateBGMTransitionGeneration() {
        bgmTransitionGeneration += 1
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

    var projectionService: ProjectionService {
        ProjectionService(
            externalScreenProvider: externalScreenProvider,
            hasExternalDisplaySnapshot: isExternalDisplayAvailable
        )
    }

    var hasExternalDisplay: Bool {
        isExternalDisplayAvailable
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
