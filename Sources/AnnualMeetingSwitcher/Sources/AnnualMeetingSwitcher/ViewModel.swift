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

    private(set) var currentProgramItem: ProgramItem?
    private(set) var currentProgramSwitchedAt: Date?
    @ObservationIgnored var runtimeIdentityStore = ViewModelRuntimeIdentityStore()
    var needsMutedMediaStartupAfterClearedProgram = false
    private(set) var programItems: [ProgramItem] = []
    var showAgendaTimeline: Bool = false {
        didSet {
            guard oldValue != showAgendaTimeline else { return }
            dispatchRuntimeFacadeAction(.operatorSetShowAgendaTimeline(showAgendaTimeline))
        }
    }

    func applyProgramQueueProjectionFromRuntime(_ items: [ProgramItem]) {
        programItems = items
    }

    func applyCurrentProgramProjectionFromRuntime(_ item: ProgramItem?, switchedAt: Date?) {
        currentProgramItem = item
        currentProgramSwitchedAt = switchedAt
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

    /// 音频输出策略。新配置默认跟随当前节目，已保存偏好仍由持久化加载覆盖。
    var audioStrategy: AudioStrategy = .followProgram {
        didSet {
            guard oldValue != audioStrategy else { return }
            dispatchRuntimeFacadeAction(.operatorSelectedAudioStrategy(audioStrategy))
        }
    }

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
    var companyDisplayName: String = "" {
        didSet {
            guard oldValue != companyDisplayName else { return }
            dispatchRuntimeFacadeAction(.operatorSetCompanyDisplayName(companyDisplayName))
        }
    }
    var cornerLogoURL: URL? {
        didSet {
            dispatchRuntimeFacadeAction(.operatorSetCornerLogoURL(cornerLogoURL))
        }
    }
    var isCornerLogoVisible: Bool = false {
        didSet {
            guard oldValue != isCornerLogoVisible else { return }
            dispatchRuntimeFacadeAction(.operatorSetCornerLogoVisible(isCornerLogoVisible))
        }
    }
    var cornerLogoImage: NSImage?
    var cornerLogoLoadPhase: CornerLogoLoadPhase = .empty
    @ObservationIgnored var cornerLogoImageLoader: @MainActor (URL) async -> Result<NSImage, CornerLogoLoadFailure> = SwitcherViewModel.defaultCornerLogoImageLoader
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
    var isAgendaTimeReminderEnabled: Bool = false {
        didSet {
            guard oldValue != isAgendaTimeReminderEnabled else { return }
            dispatchRuntimeFacadeAction(.operatorSetAgendaTimeReminderEnabled(isAgendaTimeReminderEnabled))
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
    private(set) var panicPlaybackSnapshot: PanicPlaybackSnapshot?
    var panicAudioTransitionGeneration: Int = 0
    private(set) var lastAudioRoutingTransition: AudioRoutingTransition?

    // MARK: - 引擎

    let runtime: LiveRuntimeStore
    let keynoteController = KeynoteController()
    let avCoordinator = AVPlayerCoordinator()

    let remoteControlSetup = RemoteControlSetupController()

    // MARK: - 推流窗口

    @ObservationIgnored var projectionOutputStore = ViewModelProjectionOutputStore()
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
    @ObservationIgnored var programActivationSideEffects = ProgramActivationSideEffectHandlers()
    var isPresentingAutomationAlert = false
    let automationAlertSuppressionWindow: TimeInterval = 15
    var automationAlertSuppressionUntilByAction: [String: Date] = [:]
    // MARK: - Combine / Timers

    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored let cleanupBag = ViewModelCleanupBag()
    var bgmTransitionGeneration: Int = 0
    @ObservationIgnored var activeBGMTimerGeneration: Int?
    var agendaReminderAcknowledgedItemIDs = Set<UUID>()

    // MARK: - V25: 翻页拦截器状态
    /// 翻页笔拦截开关（开启时全局拦截 PageUp/Down/左右箭头并转发给 WPS）
    var isPageInterceptEnabled: Bool = false
    @ObservationIgnored var pageInterceptSideEffectsEnabled = true
    @ObservationIgnored var testHooks = SwitcherViewModelTestHooks()
    @ObservationIgnored var runtimeFacadeDispatchSuppressionDepth = 0

    @ObservationIgnored var pageInterceptStore = ViewModelPageInterceptStore()
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
            environment: .productionPanicOwning()
        )
        configureRuntimePortHandlers(runtimePorts)
        configureDefaultProgramActivationSideEffects()
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
        configureRemoteControlCommandBridge()
    }

    deinit {
        let cleanupBag = cleanupBag
        let avCoordinator = avCoordinator

        cleanupBag.cancelAll()
        avCoordinator.shutdownNonisolated()
    }

    var runtimeSpeakerModeDuckedRatio: Float {
        speakerModeDuckedRatio
    }

    func applySupportEventsProjectionFromRuntime(_ events: [LiveSupportEvent]) {
        supportEvents = events
    }

    func updateExternalDisplayAvailabilityForProjection(_ isAvailable: Bool) {
        isExternalDisplayAvailable = isAvailable
    }

    func applyLastAudioRoutingTransitionFromRuntime(_ transition: AudioRoutingTransition?) {
        lastAudioRoutingTransition = transition
    }

    func storeMediaPlaybackCancellable(_ cancellable: AnyCancellable) {
        cancellables.insert(cancellable)
    }

    // MARK: - Tier1: 紧急切黑 State
    private(set) var isPanicMode: Bool       = false
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
    var lowerThirdRole: String = ""
    var lowerThirdOrganization: String = ""
    var lowerThirdPresets: [LowerThirdPreset] = []
}

@MainActor
extension SwitcherViewModel {
    func applyPanicProjectionFromRuntime(
        isActive: Bool,
        snapshot: PanicPlaybackSnapshot?
    ) {
        isPanicMode = isActive
        panicPlaybackSnapshot = snapshot
    }

    var outputPanicIsActive: Bool {
        runtime.bridgeMode.owns(.panic)
            ? runtime.state.panic.isActive
            : isPanicMode
    }

    func setLegacyPanicMode(_ isActive: Bool) {
        isPanicMode = isActive
    }

    func setLegacyPanicPlaybackSnapshot(_ snapshot: PanicPlaybackSnapshot?) {
        panicPlaybackSnapshot = snapshot
    }

    func markPanicSnapshotMediaStoppedIfCurrentProgram(_ currentProgramID: UUID?) {
        guard !runtime.bridgeMode.owns(.panic) else { return }
        guard panicPlaybackSnapshot?.currentProgramID == currentProgramID else { return }
        panicPlaybackSnapshot?.wasMediaPlaying = false
    }

    func markPanicSnapshotBGMStoppedIfCurrentBGM(_ currentBGMID: UUID?) {
        guard !runtime.bridgeMode.owns(.panic) else { return }
        guard panicPlaybackSnapshot?.currentBGMID == currentBGMID else { return }
        panicPlaybackSnapshot?.wasBGMPlaying = false
    }
}
