import AppKit

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
