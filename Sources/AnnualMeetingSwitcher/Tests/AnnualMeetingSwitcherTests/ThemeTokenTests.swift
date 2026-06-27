import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class ThemeTokenTests: XCTestCase {
    func testContentViewFollowsThemeOverrideInsteadOfForcingLightMode() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertFalse(content.contains(".preferredColorScheme(.light)"))
        XCTAssertTrue(content.contains(".preferredColorScheme(viewModel.themeOverride.colorScheme)"))
    }

    func testStudioThemeUsesDynamicColorProvidersForConsoleTokens() throws {
        let theme = try sourceText("Views/Theme/StudioTheme+Colors.swift")

        XCTAssertTrue(theme.contains("dynamicColor(name:"))
        XCTAssertTrue(theme.contains("NSColor(name:"))
        XCTAssertTrue(theme.contains("dynamicProvider:"))

        for token in [
            "canvasTop",
            "canvasBottom",
            "textPrimary",
            "textSecondary",
            "textTertiary",
            "borderSubtle",
            "cardBorder",
            "hairline",
            "ready",
            "live",
            "warn",
            "muted",
            "idle",
            "primary",
            "secondary",
            "base",
            "raised",
            "pressed"
        ] {
            XCTAssertTrue(theme.contains("name: \"\(token)\""), "Missing dynamic token \(token)")
        }
    }

    func testMonitorSurfaceTokensStayHardDarkAndOutOfThemeSwitching() throws {
        let theme = try sourceText("Views/Theme/StudioTheme+Colors.swift")

        XCTAssertTrue(theme.contains("static let monitorSurfaceTop = Color(red: 0.08, green: 0.09, blue: 0.13)"))
        XCTAssertTrue(theme.contains("static let monitorSurfaceBottom = Color(red: 0.03, green: 0.03, blue: 0.05)"))
    }

    func testThemeOverrideMapsToExpectedColorSchemeAndPersists() {
        XCTAssertNil(ThemeOverride.system.colorScheme)
        XCTAssertEqual(ThemeOverride.light.colorScheme, .light)
        XCTAssertEqual(ThemeOverride.dark.colorScheme, .dark)

        let suite = "ThemeTokenTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Could not create isolated defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        XCTAssertEqual(viewModel.themeOverride, .dark)

        viewModel.themeOverride = .dark
        XCTAssertEqual(defaults.string(forKey: "themeOverride"), "dark")

        let restored = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        XCTAssertEqual(restored.themeOverride, .dark)
    }

    func testThemeOverrideRestoresEveryExplicitUserChoice() {
        for option in ThemeOverride.allCases {
            let suite = "ThemeOverrideRestore-\(option.rawValue)-\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suite) else {
                XCTFail("Could not create isolated defaults")
                return
            }
            defer { defaults.removePersistentDomain(forName: suite) }

            defaults.set(option.rawValue, forKey: "themeOverride")

            let restored = SwitcherViewModel(
                loadPersistedData: true,
                enableSystemVolumeObserver: false,
                userDefaults: defaults
            )

            XCTAssertEqual(restored.themeOverride, option)
        }
    }

    func testAppAddsThemeMenuCommands() throws {
        let app = try sourceText("App.swift")

        XCTAssertTrue(app.contains("CommandGroup(after: .toolbar)"))
        XCTAssertTrue(app.contains("Menu(\"Theme\")"))
        XCTAssertTrue(app.contains("ForEach(ThemeOverride.allCases"))
        XCTAssertTrue(app.contains("viewModel.themeOverride = option"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let candidate = try sourceRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw XCTSkip("Could not locate \(relativePath)")
        }
        return try String(contentsOf: candidate, encoding: .utf8)
    }

    private func sourceRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return candidate
            }
        }
        throw XCTSkip("Could not locate app source root from test path.")
    }
}
