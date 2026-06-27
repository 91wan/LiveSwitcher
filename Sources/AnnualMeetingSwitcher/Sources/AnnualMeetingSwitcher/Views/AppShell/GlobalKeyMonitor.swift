import AppKit
import SwiftUI

// MARK: - V21 Fix #3: 全局键盘监听器（NSEvent.addLocalMonitorForEvents 可靠拦截字符键）

@MainActor
struct GlobalKeyMonitor: NSViewRepresentable {
    var viewModel: SwitcherViewModel

    func makeNSView(context: Context) -> NSView {
        let view = KeyMonitorView()
        view.viewModel = viewModel
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? KeyMonitorView)?.viewModel = viewModel
    }
}

final class KeyMonitorView: NSView {
    var viewModel: SwitcherViewModel?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installMonitor()
        } else {
            removeMonitor()
        }
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let vm = self.viewModel else { return event }
            return self.handleKey(event: event, vm: vm)
        }
    }

    private func removeMonitor() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    deinit {
        removeMonitor()
    }

    private func handleKey(event: NSEvent, vm: SwitcherViewModel) -> NSEvent? {
        guard GlobalShortcutPolicy.shouldHandleEvent(monitorWindow: window, eventWindow: event.window) else {
            return event
        }

        // MARK: - Tier1: ⌘⌥B -> 紧急切黑 (handled before modifiers guard)
        // B = keyCode 11（QWERTY 键盘上 B 键）
        if GlobalShortcutPolicy.isEmergencyPanicShortcut(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags
        ) {
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.25)) {
                    vm.togglePanicMode()
                }
            }
            return nil   // 消费此事件，不继续传递
        }

        // 跳过有修饰键的组合（避免和系统/菜单冲突）
        guard !GlobalShortcutPolicy.hasNonEmergencyShortcutModifiers(event.modifierFlags) else { return event }

        // 如果当前焦点在文本框或原生控件，不拦截，避免抢走按钮/滑杆的键盘操作
        if GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: event.window, keyCode: event.keyCode) {
            return event
        }

        let presentationShortcutsEnabled = vm.isPageInterceptEnabled || vm.currentProgramItem?.supportsPresentationControl == true

        switch event.keyCode {
        // [ = keyCode 33
        case 33:
            Task { @MainActor in vm.bgmVolumeDown() }
            return nil
        // ] = keyCode 30
        case 30:
            Task { @MainActor in vm.bgmVolumeUp() }
            return nil
        // , = keyCode 43
        case 43:
            Task { @MainActor in
                if let bgm = vm.currentBGMItem {
                    vm.toggleBGM(bgm)
                } else if let first = vm.bgmItems.first {
                    vm.toggleBGM(first)
                }
            }
            return nil
        // Space = keyCode 49
        case 49:
            Task { @MainActor in
                if let item = vm.currentProgramItem {
                    vm.togglePause(for: item)
                }
            }
            return nil
        // Left Arrow = keyCode 123
        case 123:
            guard presentationShortcutsEnabled else { return event }
            Task { @MainActor in vm.keynotePreviousSlide() }
            return nil
        // Right Arrow = keyCode 124
        case 124:
            guard presentationShortcutsEnabled else { return event }
            Task { @MainActor in vm.keynoteNextSlide() }
            return nil
        default:
            if let index = vm.programShortcutTargetIndex(forKeyCode: event.keyCode) {
                Task { @MainActor in vm.switchToProgram(at: index) }
                return nil
            }
            return event
        }
    }
}
