import AppKit
import SwiftUI
import Combine

protocol OutputWindowControlling: AnyObject {
    var onExternalDisplayUnavailable: (() -> Void)? { get set }
    func mountAnyView(rootView: AnyView)
    func show(on screen: NSScreen?, fullScreen: Bool)
    func hide()
}

// MARK: - 副屏识别工具（MacBook screen mirroring 适配）
// 识别策略：优先使用用户 pin 的副屏；否则选择物理分辨率最接近 1080P 的非主屏。
// 无副屏时返回 nil，禁止回落主屏全屏。

enum SecondScreenSelector {
    static func pickExternal(userDefaults: UserDefaults = .standard) -> NSScreen? {
        DefaultScreenSelectionPolicy().pickExternal(
            screens: NSScreen.screens,
            main: NSScreen.main,
            pinnedDisplayName: userDefaults.string(forKey: ProjectionDisplayPreferences.pinnedExternalDisplayNameKey)
        )
    }

    /// 只用于构造隐藏窗口的初始 screen；真正投射路径必须使用 pickExternal()。
    static func pickInitialWindowScreen() -> NSScreen {
        pickExternal() ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

final class NonActivatingOutputWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

enum OutputWindowPresentationPolicy {
    static func configure(_ window: NSWindow) {
        window.ignoresMouseEvents = true
        window.acceptsMouseMovedEvents = false
    }

    static func orderFront(_ window: NSWindow) {
        window.orderFrontRegardless()
    }
}

// MARK: - 推流大屏窗口控制器
// 副屏适配版（仅副屏适配相关改动，其余保持 V24 原始逻辑）：
// - 使用 SecondScreenSelector.pickExternal() 按 pin / 1080P 接近度识别副屏
// - 利用 macOS screen mirroring 通知（NSApplication.didChangeScreenParametersNotification）
//   监听屏幕热插拔，自动将推流窗口迁移到正确副屏
// - 副屏 frame 在系统坐标系中可能是负数区间，始终用 targetScreen.frame（全局坐标系）
// - contentView.frame 必须用窗口局部坐标系（从 (0,0) 开始的 bounds）
// - 绝对不使用 NSHostingController 的 intrinsic size 影响窗口尺寸
// - AppIcon 由 Info.plist 声明，不受此文件影响

final class OutputWindowController: NSWindowController, OutputWindowControlling {

    // MARK: - 屏幕变化监听（screen mirroring 热插拔适配）
    private var screenChangeObserver: NSObjectProtocol?
    var onExternalDisplayUnavailable: (() -> Void)?

    // MARK: - Init

    convenience init() {
        // 使用智能副屏选择器（pin 优先，其次按 1080P 接近度选择）
        let targetScreen = SecondScreenSelector.pickInitialWindowScreen()

        // targetScreen.frame 是全局坐标系的 rect，可能是负数起点，这完全正常
        let screenFrame = targetScreen.frame

        // NSWindow contentRect 参数接受全局坐标系（屏幕坐标系）
        let window = NonActivatingOutputWindow(
            contentRect: screenFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: targetScreen   // 明确告知 NSWindow 属于哪块屏幕
        )

        // 霸权全屏：压盖系统菜单栏
        window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)

        // 外观配置
        window.backgroundColor = .black
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.isOpaque = true
        OutputWindowPresentationPolicy.configure(window)

        self.init(window: window)

        // 注册屏幕变化通知（macOS screen mirroring 机制：监听屏幕插拔/切换）
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }

    deinit {
        if let obs = screenChangeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - 屏幕变化处理（screen mirroring 适配核心）

    /// 当 macOS 检测到屏幕参数变化（副屏接入/断开/分辨率改变）时调用
    /// 自动将推流窗口迁移到最佳副屏
    private func handleScreenChange() {
        guard let w = window, w.isVisible else { return }
        guard let targetScreen = SecondScreenSelector.pickExternal() else {
            hide()
            onExternalDisplayUnavailable?()
            return
        }
        syncWindowFrame(w, to: targetScreen, display: true)
    }

    // MARK: - 挂载 SwiftUI 视图

    /// 挂载 SwiftUI 视图到推流窗口
    /// V28 修复核心：
    /// - NSWindow.frame 是全局坐标系（副屏可能在负数区间）
    /// - contentView.frame 必须是窗口局部坐标系，即从 (0,0) 开始的 bounds
    /// - 不依赖 NSHostingController 的 intrinsicContentSize
    func mount<V: View>(rootView: V) {
        guard let w = window else { return }

        let hostingController = NSHostingController(rootView: rootView)

        // V28 关键：contentView 的 frame 用窗口 bounds（局部坐标系，origin 始终是 (0,0)）
        // 绝对不用 w.frame（那是全局坐标系，会导致视图偏移到屏幕之外）
        let localBounds = NSRect(origin: .zero, size: w.frame.size)
        hostingController.view.frame = localBounds
        hostingController.view.autoresizingMask = [.width, .height]

        w.contentViewController = hostingController
    }

    func mountAnyView(rootView: AnyView) {
        mount(rootView: rootView)
    }

    // MARK: - V28 副屏全屏方法

    /// V28 副屏全屏终极方案：
    /// - window.setFrame(targetScreen.frame, display: true) 使用全局坐标系
    /// - contentView.frame 使用窗口局部坐标系（bounds，origin = (0,0)）
    /// - 两重 async 确保 SwiftUI layout pass 之后也保持正确
    func show(on screen: NSScreen? = nil, fullScreen: Bool = false) {
        guard let w = window else { return }

        // 确定目标屏幕：优先使用传入的外接屏，否则用智能副屏选择器。
        // 无副屏时直接隐藏并回调，绝不回落主屏全屏。
        guard let targetScreen = resolveCurrentTargetScreen(preferredScreen: screen) else {
            hide()
            onExternalDisplayUnavailable?()
            return
        }

        // 副屏在全局坐标系中的精确 frame（可能是负数起点，完全正常）
        let screenFrame = targetScreen.frame

        // ── 第一重：立即 setFrame（全局坐标系） ──
        w.setFrame(screenFrame, display: false)

        // ── 第二重：显示窗口后强制 contentView 使用局部坐标系 ──
        OutputWindowPresentationPolicy.orderFront(w)

        // contentView 的 frame 必须从 (0,0) 开始，大小等于屏幕尺寸
        w.contentView?.frame = NSRect(origin: .zero, size: screenFrame.size)

        // ── 第三重：异步校正（对抗 SwiftUI layout pass 的干扰） ──
        DispatchQueue.main.async { [weak self, weak w, weak screen] in
            guard let self, let w else { return }
            self.syncWindowFrameToCurrentDisplay(
                w,
                preferredScreen: screen,
                display: true
            )
        }

        // ── 第四重：稍后再确认（应对双屏初始化延迟） ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak w, weak screen] in
            guard let self, let w, w.isVisible else { return }
            self.syncWindowFrameToCurrentDisplay(
                w,
                preferredScreen: screen,
                display: true
            )
        }
    }

    private func resolveCurrentTargetScreen(preferredScreen: NSScreen?) -> NSScreen? {
        if let preferredScreen,
           NSScreen.screens.contains(where: { $0 == preferredScreen }) {
            return preferredScreen
        }
        return SecondScreenSelector.pickExternal()
    }

    private func syncWindowFrameToCurrentDisplay(
        _ window: NSWindow,
        preferredScreen: NSScreen?,
        display: Bool
    ) {
        guard let targetScreen = resolveCurrentTargetScreen(preferredScreen: preferredScreen) else {
            hide()
            onExternalDisplayUnavailable?()
            return
        }
        syncWindowFrame(window, to: targetScreen, display: display)
    }

    private func syncWindowFrame(_ window: NSWindow, to screen: NSScreen, display: Bool) {
        let screenFrame = screen.frame
        if window.frame != screenFrame {
            window.setFrame(screenFrame, display: display)
        }
        window.contentView?.frame = NSRect(origin: .zero, size: screenFrame.size)
    }

    /// 隐藏推流窗口
    func hide() {
        window?.orderOut(nil)
    }

    /// 切换显示/隐藏
    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }
}

// MARK: - 推流输出内容视图

/// 推流大屏展示的 SwiftUI 视图（内容层）
@MainActor
struct OutputView: View {
    @Environment(SwitcherViewModel.self) var viewModel

    var body: some View {
        let displayState = OutputDisplayState.make(from: viewModel)

        ZStack {
            // 背景：黑底或壁纸
            backgroundLayer

            // 媒体内容层
            mediaContentLayer(displayState: displayState)

            OutputOverlayLayer(displayState: displayState)
                .equatable()
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: displayState.isPanicMode)
        .animation(.easeInOut(duration: 1.0), value: displayState.isFadeToBlackActive)
        .animation(.easeInOut(duration: 0.25), value: displayState.isCountdownActive)
        .animation(.easeInOut(duration: 0.25), value: displayState.isTickerActive)
        .animation(.easeInOut(duration: 0.25), value: displayState.isLowerThirdVisible)
    }

    // MARK: Private Layers

    @ViewBuilder
    private var backgroundLayer: some View {
        if let wallpaper = viewModel.backgroundImage {
            // V32 等比填满：.scaledToFill() 等比放大直到填满屏幕，左右可能裁切，无黑边
            Image(nsImage: wallpaper)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
        } else {
            Color.black
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func mediaContentLayer(displayState: OutputDisplayState) -> some View {
        // AVPlayer 视频层：始终在视图树中
        // 在 AppKit 层通过 nsView.isHidden 控制 AVPlayerLayer 显隐，
        // 避免 Metal 合成层"穿透" opacity 显示最后一帧。
        OutputVideoPlayerView(coordinator: viewModel.avCoordinator)

        // HTML 大屏展示层（与视频层互斥）
        if let htmlURL = displayState.currentHTMLURL {
            OutputWebView(url: htmlURL)
                .transition(.opacity)
        }
    }
}

private struct OutputOverlayLayer: View, Equatable {
    let displayState: OutputDisplayState

    var body: some View {
        Group {
            // MARK: - Tier1: 叠层渲染（倒计时 + 游动字幕）
            if displayState.isCountdownActive {
                CountdownOverlay()
                    .transition(.opacity)
            }
            if displayState.isTickerActive {
                TickerOverlay()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            }

            // MARK: - V27: Lower Third 人名条（下三分之一条）
            if displayState.isLowerThirdVisible {
                LowerThirdView(
                    name: displayState.lowerThirdName,
                    title: displayState.lowerThirdTitle,
                    isVisible: displayState.isLowerThirdVisible
                )
                .transition(.opacity)
                .zIndex(OutputLayerZIndex.lowerThird)
            }

            OutputCornerLogoLayer(
                url: displayState.cornerLogoURL,
                position: displayState.cornerLogoPosition
            )
            .zIndex(OutputLayerZIndex.cornerLogo)

            if displayState.isFadeToBlackActive {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(OutputLayerZIndex.fadeToBlack)
                    .accessibilityLabel("Fade to black active")
            }

            // MARK: - Tier1: Panic 黑屏遮罩（最高优先级，必须在最顶层）
            if displayState.isPanicMode {
                PanicLayer()
                    .transition(.opacity)
                    .zIndex(OutputLayerZIndex.panic)
            }
        }
    }
}

private struct OutputCornerLogoLayer: View {
    let url: URL?
    let position: CornerLogoPosition

    var body: some View {
        AsyncLocalImage(url: url) {
            EmptyView()
        } content: { image in
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
                .accessibilityLabel("Corner logo")
        }
    }
}

// MARK: - AVPlayer 副屏专用封装

import AVKit
import AVFoundation

/// V34 副屏输出（等比填满版）：
/// - videoGravity = .resizeAspectFill
/// - 仅根据是否仍加载媒体来控制 AVPlayerView 显隐
/// - 暂停时保持播放器层挂载，避免恢复播放时出现有声音但黑屏
struct OutputVideoPlayerView: NSViewRepresentable {
    let coordinator: AVPlayerCoordinator

    func makeCoordinator() -> VisibilityCoordinator {
        VisibilityCoordinator()
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = coordinator.player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspectFill
        view.autoresizingMask = [.width, .height]
        context.coordinator.bind(avCoordinator: coordinator, to: view)
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = coordinator.player
        nsView.videoGravity = .resizeAspectFill
        nsView.isHidden = !VideoLayerVisibilityModel.shouldShowVideoLayer(
            sourceKind: coordinator.currentURL.map { _ in .media },
            hasLoadedMedia: coordinator.hasLoadedMedia
        )
    }

    @MainActor
    class VisibilityCoordinator {
        private var cancellable: AnyCancellable?

        func bind(avCoordinator: AVPlayerCoordinator, to view: AVPlayerView) {
            cancellable = avCoordinator.$hasLoadedMedia
                .receive(on: DispatchQueue.main)
                .sink { [weak view] hasLoadedMedia in
                    view?.isHidden = !VideoLayerVisibilityModel.shouldShowVideoLayer(
                        sourceKind: avCoordinator.currentURL.map { _ in .media },
                        hasLoadedMedia: hasLoadedMedia
                    )
                }
        }
    }
}

// MARK: - HTML WebView 桥接（供翻页拦截器注入 JS）

final class HTMLWebViewBridge {
    static let shared = HTMLWebViewBridge()
    private init() {}

    private let stateLock = NSLock()
    private var activeWebViewID: ObjectIdentifier?
    @MainActor private weak var currentWebView: WKWebView?

    var hasActiveWebView: Bool {
        stateLock.lock()
        let hasWebView = activeWebViewID != nil
        stateLock.unlock()
        return hasWebView
    }

    @MainActor
    func register(_ webView: WKWebView) {
        currentWebView = webView
        updateActiveWebViewID(ObjectIdentifier(webView))
    }

    @MainActor
    func clearIfCurrent(_ candidate: WKWebView) {
        if currentWebView === candidate {
            currentWebView = nil
            updateActiveWebViewID(nil)
        }
    }

    @MainActor
    func isCurrent(_ candidate: WKWebView) -> Bool {
        currentWebView === candidate
    }

    /// 注入翻页事件（ArrowRight=下一页，ArrowLeft=上一页）
    func dispatchArrowKey(isNext: Bool) {
        let key = isNext ? "ArrowRight" : "ArrowLeft"
        let js = """
        (function() {
            var e = new KeyboardEvent('keydown', {
                key: '\(key)',
                code: '\(isNext ? "ArrowRight" : "ArrowLeft")',
                keyCode: \(isNext ? 39 : 37),
                bubbles: true,
                cancelable: true
            });
            document.dispatchEvent(e);
            window.dispatchEvent(e);
        })();
        """
        Task { @MainActor [weak self] in
            guard let webView = self?.currentWebView else { return }
            _ = try? await webView.evaluateJavaScript(js)
        }
    }

    private func updateActiveWebViewID(_ id: ObjectIdentifier?) {
        stateLock.lock()
        activeWebViewID = id
        stateLock.unlock()
    }
}

// MARK: - HTML 大屏展示视图（WKWebView 封装，防御版）

import WebKit

/// 将本地 HTML 文件渲染到副屏，支持读取同目录资源（CSS/JS/图片）
/// 防御版：独立进程池 + Coordinator 强引用 + dismantleNSView 清场，防内存泄漏与双实例
struct OutputWebView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        #if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        // 注：WKProcessPool 在 macOS 12+ 已废弃且无效，进程隔离由系统管理
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.configure(for: url)
        HTMLWebViewBridge.shared.register(webView)   // 注册到 bridge，供翻页拦截器注入 JS
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.configure(for: url)
        // 仅在 URL 真正变化时重载，防止 SwiftUI diff 触发无效重载
        guard WebNavigationPolicy.shouldReloadFileURL(current: nsView.url, target: url) else { return }
        nsView.stopLoading()
        nsView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        // SwiftUI 销毁 View 时强制清空 WebView，防离屏内存泄漏
        nsView.stopLoading()
        nsView.loadHTMLString("", baseURL: nil)
        coordinator.webView = nil
        HTMLWebViewBridge.shared.clearIfCurrent(nsView)
    }

    class Coordinator: NSObject {
        // 强引用持有，防止 ARC 在 SwiftUI diff 过程中提前释放
        var webView: WKWebView?
        private(set) var allowedRootDirectory: URL?

        func configure(for url: URL) {
            allowedRootDirectory = url.deletingLastPathComponent()
        }
    }
}

extension OutputWebView.Coordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        WebNavigationPolicy.shouldAllowNavigation(
            url: navigationAction.request.url,
            allowedRoot: allowedRootDirectory
        ) ? .allow : .cancel
    }
}

// MARK: - ContentView 中使用的监视器 VideoPlayerView（保持不变）

struct VideoPlayerView: NSViewRepresentable {
    let coordinator: AVPlayerCoordinator

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = coordinator.player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = coordinator.player
    }
}
