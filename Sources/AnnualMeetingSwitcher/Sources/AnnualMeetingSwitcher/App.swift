import AppKit
import SwiftUI

// NOTE: Entry point is in main.swift (SPM executable target).
// Do NOT add @main here.

struct LiveSwitcherApp: App {
    @NSApplicationDelegateAdaptor(LiveSwitcherAppDelegate.self) private var appDelegate
    @State private var viewModel: SwitcherViewModel
    @Environment(\.openWindow) private var openWindow

    init() {
        let viewModel = Self.makeViewModel()
        _viewModel = State(wrappedValue: viewModel)
        LiveSwitcherAppDelegate.sharedViewModel = viewModel
    }

    var body: some Scene {
        WindowGroup("LiveSwitcher", id: "main-console") {
            ContentView()
                .environment(viewModel)
                .frame(minWidth: AppConfiguration.minWindowWidth,
                       minHeight: AppConfiguration.minWindowHeight)
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Menu("Theme") {
                    ForEach(ThemeOverride.allCases) { option in
                        Button(option.menuTitle) {
                            viewModel.themeOverride = option
                        }
                        .keyboardShortcut(themeShortcut(for: option), modifiers: [.command, .option])
                        .disabled(viewModel.themeOverride == option)
                    }
                }
            }

            CommandGroup(after: .pasteboard) {
                Button("从剪贴板粘贴主持人") {
                    if let text = NSPasteboard.general.string(forType: .string),
                       viewModel.importLowerThirdSpeakersFromClipboardText(text) != nil {
                        viewModel.navigateToSetup(.overlays)
                        viewModel.overlayComposerState.selectedKind = .lowerThird
                    } else {
                        NSSound.beep()
                    }
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }

            CommandMenu("模式") {
                Button("准备") {
                    viewModel.consoleMode = .setup
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(viewModel.consoleMode == .setup)

                Button("现场") {
                    viewModel.consoleMode = .live
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(viewModel.consoleMode == .live)
            }

            CommandMenu("准备页面") {
                Button("节目单") {
                    viewModel.navigateToSetup(.preview)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("音频") {
                    viewModel.navigateToSetup(.audioMixer)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("叠层") {
                    viewModel.navigateToSetup(.overlays)
                }
                .keyboardShortcut("3", modifiers: .command)
            }

            CommandMenu("现场控制") {
                Button("打开现场安全台") {
                    openWindow(id: "safety-cockpit")
                }
                .keyboardShortcut("0", modifiers: [.command, .option])

                Divider()

                Button(viewModel.isSpeakerMode ? "关闭主讲人模式" : "开启主讲人模式") {
                    viewModel.toggleSpeakerMode()
                }
                .keyboardShortcut("m", modifiers: [.command, .option])

                Button(viewModel.isPanicMode ? "关闭紧急切黑" : "开启紧急切黑") {
                    viewModel.togglePanicMode()
                }
                .keyboardShortcut("b", modifiers: [.command, .option])

                Button(viewModel.isPageInterceptEnabled ? "关闭 PPT 模式" : "开启 PPT 模式") {
                    viewModel.togglePPTMode(source: .command)
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
            }
        }
        .windowResizability(.contentMinSize)

        Window("现场安全台", id: "safety-cockpit") {
            SafetyCockpitView()
                .environment(viewModel)
        }
        .defaultSize(width: 880, height: 720)
        .windowResizability(.contentMinSize)
    }

    private static func makeViewModel() -> SwitcherViewModel {
        let environment = ProcessInfo.processInfo.environment
        guard let suiteName = environment["LIVESWITCHER_USER_DEFAULTS_SUITE"],
              !suiteName.isEmpty,
              let userDefaults = UserDefaults(suiteName: suiteName) else {
            return SwitcherViewModel()
        }
        return SwitcherViewModel(userDefaults: userDefaults)
    }

    private func themeShortcut(for option: ThemeOverride) -> KeyEquivalent {
        switch option {
        case .system:
            return "0"
        case .light:
            return "1"
        case .dark:
            return "2"
        }
    }
}

final class LiveSwitcherAppDelegate: NSObject, NSApplicationDelegate {
    static var sharedViewModel: SwitcherViewModel?
    private static var fallbackMainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            Self.ensureMainWindowIfNeeded(viewModel: Self.sharedViewModel, activate: true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Task { @MainActor in
                Self.ensureMainWindowIfNeeded(viewModel: Self.sharedViewModel, activate: true)
            }
        }
        return true
    }

    @MainActor
    static func ensureMainWindowIfNeeded(viewModel: SwitcherViewModel?, activate: Bool) {
        if let existingMainWindow = NSApp.windows.first(where: isMainConsoleWindow) {
            bringMainWindowToFront(existingMainWindow, activate: activate)
            if isUsablyVisibleMainWindow(existingMainWindow) {
                return
            }
            closeUnusableMainWindow(existingMainWindow)
        }

        if let fallbackMainWindow, isUsablyVisibleMainWindow(fallbackMainWindow) {
            bringMainWindowToFront(fallbackMainWindow, activate: activate)
            return
        }
        if let fallbackMainWindow {
            closeUnusableMainWindow(fallbackMainWindow)
        }

        guard let viewModel else { return }

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: AppConfiguration.minWindowWidth,
                height: AppConfiguration.minWindowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LiveSwitcher"
        window.identifier = NSUserInterfaceItemIdentifier("main-console")
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = NSSize(width: AppConfiguration.minWindowWidth, height: AppConfiguration.minWindowHeight)
        window.contentView = NSHostingView(
            rootView: ContentView()
                .environment(viewModel)
                .frame(
                    minWidth: AppConfiguration.minWindowWidth,
                    minHeight: AppConfiguration.minWindowHeight
                )
        )
        window.center()
        bringMainWindowToFront(window, activate: activate)
        fallbackMainWindow = window
    }

    @MainActor
    private static func bringMainWindowToFront(_ window: NSWindow, activate: Bool) {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private static func isUsablyVisibleMainWindow(_ window: NSWindow) -> Bool {
        MainWindowFallbackPolicy.shouldReuseMainWindow(
            isVisible: window.isVisible,
            isMiniaturized: window.isMiniaturized,
            isOcclusionVisible: window.occlusionState.contains(.visible)
        )
    }

    private static func closeUnusableMainWindow(_ window: NSWindow) {
        window.orderOut(nil)
        window.close()
    }

    private static func isMainConsoleWindow(_ window: NSWindow) -> Bool {
        let identifier = window.identifier?.rawValue ?? ""
        return identifier.hasPrefix("main-console") || window.title == "LiveSwitcher"
    }
}
