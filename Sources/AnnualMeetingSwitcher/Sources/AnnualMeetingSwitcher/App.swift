import SwiftUI

// NOTE: Entry point is in main.swift (SPM executable target).
// Do NOT add @main here.

struct LiveSwitcherApp: App {
    @StateObject private var viewModel = Self.makeViewModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("LiveSwitcher", id: "main-console") {
            ContentView()
                .environmentObject(viewModel)
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

                Button(viewModel.isPanicMode ? "关闭老板键" : "开启老板键") {
                    viewModel.togglePanicMode()
                }
                .keyboardShortcut("b", modifiers: [.command, .option])

                Button(viewModel.isPageInterceptEnabled ? "关闭 PPT 模式" : "开启 PPT 模式") {
                    viewModel.isPageInterceptEnabled.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
            }
        }
        .windowResizability(.contentMinSize)

        Window("Live Safety Cockpit", id: "safety-cockpit") {
            SafetyCockpitView()
                .environmentObject(viewModel)
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
