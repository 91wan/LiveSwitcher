import AppKit
import SwiftUI

protocol OutputWindowControlling: AnyObject {
    var onExternalDisplayUnavailable: (() -> Void)? { get set }
    func mountAnyView(rootView: AnyView)
    func show(on screen: NSScreen?)
    func hide()
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
    private var displayLossReporter = OutputDisplayLossReporter()
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
            let wasVisible = w.isVisible
            hide()
            reportExternalDisplayUnavailable(windowIsVisible: wasVisible)
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
    func show(on screen: NSScreen? = nil) {
        guard let w = window else { return }

        // 确定目标屏幕：优先使用传入的外接屏，否则用智能副屏选择器。
        // 无副屏时直接隐藏并回调，绝不回落主屏全屏。
        guard let targetScreen = resolveCurrentTargetScreen(preferredScreen: screen) else {
            hide()
            reportExternalDisplayUnavailable(windowIsVisible: true)
            return
        }

        // 副屏在全局坐标系中的精确 frame（可能是负数起点，完全正常）
        let screenFrame = targetScreen.frame

        // ── 第一重：立即 setFrame（全局坐标系） ──
        w.setFrame(screenFrame, display: false)

        // ── 第二重：显示窗口后强制 contentView 使用局部坐标系 ──
        OutputWindowPresentationPolicy.orderFront(w)
        displayLossReporter.resetAfterSuccessfulShow()

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
            let wasVisible = window.isVisible
            hide()
            reportExternalDisplayUnavailable(windowIsVisible: wasVisible)
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

    private func reportExternalDisplayUnavailable(windowIsVisible: Bool) {
        guard displayLossReporter.shouldReportDisplayUnavailable(windowIsVisible: windowIsVisible) else { return }
        onExternalDisplayUnavailable?()
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
