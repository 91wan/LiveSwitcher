import SwiftUI
import Combine
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import Carbon         // V25: 翻页拦截器 CGEventTap
import ApplicationServices // V25: AXIsProcessTrusted

// MARK: - 节目单数据模型

struct ProgramItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var subtitle: String
    /// 媒体文件 URL（可选）
    var sourceURL: URL?

    init(id: UUID = UUID(), title: String, subtitle: String = "", sourceURL: URL? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.sourceURL = sourceURL
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

@MainActor
final class SwitcherViewModel: ObservableObject {

    // MARK: - 主窗口导航

    @Published var selectedMainTab: MainConsoleTab = .preview

    // MARK: - 节目状态

    @Published var currentProgramItem: ProgramItem? {
        didSet { applyAudioRouting() }
    }
    @Published var programItems: [ProgramItem] = []

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

    /// 音频输出策略。默认保持“混合”，与当前已存在的实际行为一致。
    @Published var audioStrategy: AudioStrategy = .mixed {
        didSet {
            applyAudioRouting()
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
            if let url = activeWallpaperURL {
                backgroundImage = NSImage(contentsOf: url)
            } else {
                backgroundImage = nil
            }
        }
    }

    // MARK: - BGM 列表

    @Published var bgmItems: [BGMItem] = []
    @Published var currentBGMItem: BGMItem?
    @Published var isBGMPlaying: Bool = false
    @Published var isBGMAudioTakeoverActive: Bool = false
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

    /// BGM 进度（0.0 ~ 1.0），由定时器驱动
    @Published var bgmProgress: Double = 0.0
    @Published var bgmCurrentTime: Double = 0.0
    @Published var bgmDuration: Double? = nil

    /// BGM 播放器
    var bgmAudioPlayer: AVAudioPlayer?
    var bgmFallbackPlayer: AVPlayer = AVPlayer()

    // MARK: - 引擎

    let keynoteController = KeynoteController()
    let avCoordinator = AVPlayerCoordinator()

    // MARK: - 推流窗口

    private var outputWindowController: OutputWindowControlling?
    var externalScreenProvider: () -> NSScreen? = {
        SecondScreenSelector.pickExternal()
    }
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
    private var bgmFallbackVolumeFadeTask: Task<Void, Never>?
    private var systemVolumeObserver: SystemVolumeObserver?
    private let supportEventLimit = 80

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
        static let bgmList = "bgmList_paths"
        static let bgmListCategories = "bgmList_categories"
        static let wallpapers = "backgroundWallpapers_paths"
        static let activeWallpaper = "activeWallpaper_path"
        static let audioStrategy = "audioStrategy"
        static let speakerMode = "speakerMode"
        static let autoPlayNextVideoOnEnd = "autoPlayNextVideoOnEnd"
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
        if enableSystemVolumeObserver {
            setupSystemVolumeObserver()
        }
        bgmDelegate.viewModel = self // V21 Fix #1: 绑定 delegate
    }

    deinit {
        mediaVolumeFadeTask?.cancel()
        bgmFallbackVolumeFadeTask?.cancel()
        systemVolumeObserver?.stop()
        let avCoordinator = avCoordinator
        Task { @MainActor in
            avCoordinator.shutdown()
        }
    }

    // MARK: - 音量实际应用（Fix Issue #7/#8）

    func applyMasterVolume() {
        applyAudioRouting()
    }

    func applyBGMVolume() {
        applyAudioRouting()
    }

    func effectiveMediaOutputVolume() -> Float {
        audioRoutingOutput.media
    }

    func effectiveBGMOutputVolume() -> Float {
        audioRoutingOutput.bgm
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

        let effectiveBGM = effectiveBGMOutputVolume()
        if let bgmFadeDuration, let bgmAudioPlayer {
            bgmAudioPlayer.setVolume(effectiveBGM, fadeDuration: bgmFadeDuration)
        } else {
            bgmAudioPlayer?.volume = effectiveBGM
        }

        if let bgmFadeDuration {
            fadeBGMFallbackVolume(to: effectiveBGM, duration: bgmFadeDuration)
        } else {
            bgmFallbackVolumeFadeTask?.cancel()
            bgmFallbackPlayer.volume = effectiveBGM
        }
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

    private func programItemSupportsSeeking(_ item: ProgramItem) -> Bool {
        item.sourceKind.supportsSeeking
    }

    var projectionService: ProjectionService {
        ProjectionService(externalScreenProvider: externalScreenProvider)
    }

    var hasExternalDisplay: Bool {
        projectionService.hasExternalDisplay
    }

    // MARK: - 持久化

    func saveData() {
        let persistentProgramItems = ProgramQueueStore.persistentProgramItems(from: programItems)
        let pushPaths = persistentProgramItems.compactMap { $0.sourceURL?.path }
        let pushSubtitles = persistentProgramItems.map { $0.subtitle }
        let pushTitles = persistentProgramItems.map { $0.title }
        userDefaults.set(pushPaths, forKey: UDKeys.pushList)
        userDefaults.set(pushTitles, forKey: "pushList_titles")
        userDefaults.set(pushSubtitles, forKey: "pushList_subtitles")

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
    }

    func loadData() {
        // Fix Issue #2: loadData is called from @MainActor init, all @Published updates are safe
        if let paths = userDefaults.stringArray(forKey: UDKeys.pushList) {
            let titles = userDefaults.stringArray(forKey: "pushList_titles") ?? []
            let subtitles = userDefaults.stringArray(forKey: "pushList_subtitles") ?? []
            programItems.append(
                contentsOf: ProgramQueueStore.restoredProgramItems(
                    paths: paths,
                    titles: titles,
                    subtitles: subtitles
                )
            )
        }

        if let paths = userDefaults.stringArray(forKey: UDKeys.bgmList) {
            let categories = userDefaults.stringArray(forKey: UDKeys.bgmListCategories) ?? []
            let titles = userDefaults.stringArray(forKey: "bgmList_titles") ?? []
            for (i, path) in paths.enumerated() {
                let url = URL(fileURLWithPath: path)
                guard FileManager.default.fileExists(atPath: path) else { continue }
                let catRaw = i < categories.count ? categories[i] : BGMCategory.warmUp.rawValue
                let cat = BGMCategory(rawValue: catRaw) ?? .warmUp
                let title = i < titles.count ? titles[i] : url.deletingPathExtension().lastPathComponent
                let item = BGMItem(title: title, url: url, category: cat)
                bgmItems.append(item)
            }
        }

        if let paths = userDefaults.stringArray(forKey: UDKeys.wallpapers) {
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

        if let storedAudioStrategy = userDefaults.string(forKey: UDKeys.audioStrategy),
           let audioStrategy = AudioStrategy(rawValue: storedAudioStrategy) {
            self.audioStrategy = audioStrategy
        }

        if userDefaults.object(forKey: UDKeys.speakerMode) != nil {
            isSpeakerMode = userDefaults.bool(forKey: UDKeys.speakerMode)
        }

        if userDefaults.object(forKey: UDKeys.autoPlayNextVideoOnEnd) != nil {
            autoPlayNextVideoOnEnd = userDefaults.bool(forKey: UDKeys.autoPlayNextVideoOnEnd)
        }
    }

    // MARK: - 播毕回调绑定

    private func setupPlayerCoordinator() {
        avCoordinator.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyAudioRouting()
            }
            .store(in: &cancellables)

        avCoordinator.onPlaybackEnded = { [weak self] in
            self?.handlePlaybackEnded()
        }
    }

    // MARK: - 节目操作

    func switchToProgram(_ item: ProgramItem) {
        switch item.sourceKind {
        case .unsupported:
            return
        case .media:
            guard let url = item.sourceURL else { return }
            currentProgramItem = item
            currentHTMLURL = nil              // 清空 HTML 层
            avCoordinator.load(url: url)
            avCoordinator.play()
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
        case .html, .unsupported:
            return
        case .media:
            break
        }

        // 普通视频
        if avCoordinator.isPlaying {
            avCoordinator.pause()
        } else {
            avCoordinator.play()
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

    func seekProgramItemToEnd(_ item: ProgramItem) {
        if currentProgramItem?.id == item.id && programItemSupportsSeeking(item) {
            programSeekToEndHandler()
        }
    }

    func addProgramItem(_ item: ProgramItem) {
        programItems.append(item)
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

    private func isSupportedWallpaperImage(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return false }
        return type.conforms(to: .image)
    }

    // MARK: - BGM 操作

    @discardableResult
    func addBGMItem(_ item: BGMItem) -> Bool {
        guard BGMDuplicatePolicy.decision(for: item.url, existingItems: bgmItems) != .duplicateURL else {
            recordSupportEvent(kind: .bgmImportSkippedDuplicate, detail: "reason=duplicateURL")
            return false
        }
        bgmItems.append(item)
        saveData()
        return true
    }

    func removeBGMItem(_ item: BGMItem) {
        bgmItems.removeAll { $0.id == item.id }
        if currentBGMItem?.id == item.id {
            stopBGMTimer()
            isBGMAudioTakeoverActive = false
            fadeMediaVolume(to: effectiveMediaOutputVolume(), duration: liveAudioFadeDuration)
            bgmAudioPlayer?.stop()
            bgmAudioPlayer?.delegate = nil
            bgmAudioPlayer = nil
            bgmFallbackVolumeFadeTask?.cancel()
            bgmFallbackPlayer.volume = 0
            bgmFallbackPlayer.pause()
            bgmFallbackPlayer.replaceCurrentItem(with: nil)
            currentBGMItem = nil
            isBGMPlaying = false
            bgmProgress = 0
            bgmCurrentTime = 0
            bgmDuration = nil
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
        bgmProgress = 0
        bgmCurrentTime = 0
    }

    func toggleBGM(_ item: BGMItem) {
        if currentBGMItem?.id == item.id {
            if isBGMPlaying {
                // BGM 停止时只解除临时接管，不改变用户选择的混音策略。
                let fadeDur = liveAudioFadeDuration
                isBGMPlaying = false
                isBGMAudioTakeoverActive = false
                LiveSwitcherTelemetry.bgmTakeoverChanged(isActive: false)
                recordSupportEvent(kind: .bgmTakeoverChanged, detail: "isActive=false")
                fadeMediaVolume(to: effectiveMediaOutputVolume(), duration: fadeDur)
                bgmAudioPlayer?.setVolume(0, fadeDuration: fadeDur)
                let capturedPlayer = bgmAudioPlayer
                Task { @MainActor in
                    if fadeDur > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(fadeDur * 1_000_000_000))
                    }
                    capturedPlayer?.pause()
                }
                fadeBGMFallbackVolume(to: 0, duration: fadeDur)
                let stoppingItemID = item.id
                Task { @MainActor [weak self] in
                    if fadeDur > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(fadeDur * 1_000_000_000))
                    }
                    guard let self else { return }
                    if self.currentBGMItem?.id == stoppingItemID && !self.isBGMPlaying {
                        self.bgmFallbackPlayer.pause()
                    }
                }
                stopBGMTimer()
            } else {
                // BGM 恢复播放时临时接管现场音频：媒体淡出，BGM 淡入。
                let fadeDur = liveAudioFadeDuration
                isBGMPlaying = true
                isBGMAudioTakeoverActive = true
                LiveSwitcherTelemetry.bgmTakeoverChanged(isActive: true)
                recordSupportEvent(kind: .bgmTakeoverChanged, detail: "isActive=true")
                bgmAudioPlayer?.volume = 0
                bgmAudioPlayer?.play()
                bgmFallbackPlayer.volume = 0
                bgmFallbackPlayer.play()
                applyAudioRouting(mediaFadeDuration: fadeDur, bgmFadeDuration: fadeDur)
                startBGMTimer()
            }
        } else {
            stopBGMTimer()
            let fadeDur = liveAudioFadeDuration

            // 切歌时取消旧 fallback fade，避免旧任务回写新曲目的目标音量。
            bgmFallbackVolumeFadeTask?.cancel()
            if let oldPlayer = bgmAudioPlayer {
                oldPlayer.setVolume(0, fadeDuration: fadeDur)
                let capturedOld = oldPlayer
                Task { @MainActor in
                    if fadeDur > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(fadeDur * 1_000_000_000))
                    }
                    capturedOld.stop()
                }
            }
            bgmAudioPlayer?.delegate = nil
            bgmAudioPlayer = nil
            bgmFallbackPlayer.pause()
            bgmFallbackPlayer.replaceCurrentItem(with: nil)

            currentBGMItem = item
            isBGMPlaying = true
            isBGMAudioTakeoverActive = true
            LiveSwitcherTelemetry.bgmTakeoverChanged(isActive: true)
            recordSupportEvent(kind: .bgmTakeoverChanged, detail: "isActive=true")
            let targetVolume = effectiveBGMOutputVolume()

            if let player = try? AVAudioPlayer(contentsOf: item.url) {
                player.volume = 0  // Bug Fix #1: 从0开始，淡入至目标音量
                player.numberOfLoops = 0   // V21 Fix #1: 0 = 播完停，delegate 触发自动下一首
                player.delegate = bgmDelegate  // V21 Fix #1: 播完回调
                player.prepareToPlay()
                player.play()
                player.setVolume(targetVolume, fadeDuration: fadeDur)  // Bug Fix #1: 淡入
                bgmAudioPlayer = player
                bgmDuration = player.duration > 0 ? player.duration : nil
            } else {
                let avItem = AVPlayerItem(url: item.url)
                bgmFallbackPlayer.replaceCurrentItem(with: avItem)
                bgmFallbackPlayer.volume = 0
                bgmFallbackPlayer.play()
                bgmDuration = nil
            }
            bgmProgress = 0
            bgmCurrentTime = 0
            applyAudioRouting(mediaFadeDuration: fadeDur, bgmFadeDuration: fadeDur)
            startBGMTimer()
        }
    }

    // MARK: - BGM Progress Timer

    private func startBGMTimer() {
        stopBGMTimer()
        bgmProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateBGMProgress()
            }
        }
    }

    func stopBGMTimer() {
        bgmProgressTimer?.invalidate()
        bgmProgressTimer = nil
    }

    func cancelBGMFallbackFade() {
        bgmFallbackVolumeFadeTask?.cancel()
        bgmFallbackVolumeFadeTask = nil
    }

    private func updateBGMProgress() {
        if let player = bgmAudioPlayer {
            bgmCurrentTime = player.currentTime
            let dur = player.duration
            bgmDuration = dur > 0 ? dur : nil
            bgmProgress = dur > 0 ? player.currentTime / dur : 0
        }
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

    // MARK: - Tier1: Panic State（老板键状态变量）
    @Published var isPanicMode: Bool       = false

    // MARK: - Tier1: Overlay State（叠层状态变量）
    @Published var overlayComposerState = OverlayComposerState()
    @Published var isCountdownActive: Bool = false
    @Published var countdownTitle: String  = "活动即将开始"
    @Published var countdownSeconds: Int   = 0
    var countdownTimer: Timer?

    @Published var isTickerActive: Bool    = false
    @Published var tickerText: String      = "Welcome · The program will begin shortly"
    @Published var tickerSpeed: Double     = 80.0

    // MARK: - V27: Lower Third（下三分之一条）状态
    @Published var isLowerThirdVisible: Bool = false
    @Published var lowerThirdName: String    = ""
    @Published var lowerThirdTitle: String   = ""
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
