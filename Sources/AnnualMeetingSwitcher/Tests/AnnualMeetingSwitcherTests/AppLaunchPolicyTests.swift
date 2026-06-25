import XCTest
@testable import LiveSwitcher

final class AppLaunchPolicyTests: XCTestCase {
    func testSwiftPMEntryPointUsesRegularActivationPolicy() throws {
        let source = try sourceText("main.swift")

        XCTAssertTrue(source.contains("import AppKit"))
        XCTAssertTrue(source.contains("NSApplication.shared.setActivationPolicy(.regular)"))
    }

    func testSwiftPMEntryPointInstallsLaunchCoordinator() throws {
        let source = try sourceText("main.swift")

        XCTAssertTrue(source.contains("private let liveSwitcherLaunchCoordinator = LiveSwitcherLaunchCoordinator()"))
        XCTAssertTrue(source.contains("liveSwitcherLaunchCoordinator.install()"))
        XCTAssertLessThan(
            source.range(of: "liveSwitcherLaunchCoordinator.install()")!.lowerBound,
            source.range(of: "LiveSwitcherApp.main()")!.lowerBound
        )
    }

    func testAppInstallsMainWindowFallbackForRestorationFailures() throws {
        let source = try sourceText("App.swift")

        XCTAssertTrue(source.contains("NSApplication.didFinishLaunchingNotification"))
        XCTAssertTrue(source.contains("NSApplication.didBecomeActiveNotification"))
        XCTAssertTrue(source.contains("ensureMainWindow(shouldScheduleDelayedCheck:"))
        XCTAssertTrue(source.contains("ensureMainWindowIfNeeded"))
        XCTAssertTrue(source.contains("isMainConsoleWindow"))
        XCTAssertTrue(source.contains("mainWindowOrigin(for: window)"))
        XCTAssertTrue(source.contains("ContentView()"))
        XCTAssertTrue(source.contains("NSHostingView"))
    }

    func testMainWindowFallbackHasSingleDelayedScheduler() throws {
        let source = try sourceText("App.swift")
        let delayedFallbackCount = source
            .components(separatedBy: "try? await Task.sleep(nanoseconds:")
            .count - 1

        XCTAssertEqual(delayedFallbackCount, 1)
        XCTAssertTrue(source.contains("Self.ensureMainWindowIfNeeded(viewModel: Self.sharedViewModel, activate: true)"))
        XCTAssertTrue(source.contains("Self.scheduleMainWindowFallback(viewModel: Self.sharedViewModel, delayNanoseconds: 700_000_000)"))
        XCTAssertFalse(source.contains("900_000_000"))
    }

    func testFallbackViewModelReferenceIsStrongUntilWindowExists() throws {
        let source = try sourceText("App.swift")

        XCTAssertTrue(source.contains("LiveSwitcherLaunchCoordinator.sharedViewModel = viewModel"))
        XCTAssertTrue(source.contains("static var sharedViewModel: SwitcherViewModel?"))
        XCTAssertTrue(source.contains("@MainActor\n    private static func makeViewModel() -> SwitcherViewModel"))
        XCTAssertFalse(source.contains("static weak var sharedViewModel"))
    }

    func testFallbackReordersRestoredMainWindowInsteadOfReturningInvisible() throws {
        let source = try sourceText("App.swift")

        XCTAssertTrue(source.contains("if let existingMainWindow = NSApp.windows.first(where: isMainConsoleWindow)"))
        XCTAssertTrue(source.contains("bringMainWindowToFront(existingMainWindow, activate: activate)"))
        XCTAssertTrue(source.contains("if origin == .fallback, isUsablyVisibleMainWindow(existingMainWindow)"))
        XCTAssertTrue(source.contains("mainWindowOrigin(for: existingMainWindow)"))
        XCTAssertTrue(source.contains("MainWindowFallbackPolicy.shouldCloseUnusableMainWindow(origin: origin)"))
        XCTAssertTrue(source.contains("window.collectionBehavior.insert(.moveToActiveSpace)"))
        XCTAssertFalse(source.contains("if NSApp.windows.contains(where: isMainConsoleWindow) {\n            return\n        }"))
    }

    func testVisibleOccludedMainWindowIsReusable() {
        XCTAssertTrue(
            MainWindowFallbackPolicy.shouldReuseMainWindow(
                isVisible: true,
                isMiniaturized: false,
                isOcclusionVisible: false
            )
        )
    }

    func testHiddenOrMiniaturizedMainWindowIsNotReusableUntilOrderedFront() {
        XCTAssertFalse(
            MainWindowFallbackPolicy.shouldReuseMainWindow(
                isVisible: false,
                isMiniaturized: false,
                isOcclusionVisible: false
            )
        )
        XCTAssertFalse(
            MainWindowFallbackPolicy.shouldReuseMainWindow(
                isVisible: true,
                isMiniaturized: true,
                isOcclusionVisible: true
            )
        )
    }

    func testAnyUnusableMainWindowMayBeClosedAfterReorderFails() {
        XCTAssertTrue(MainWindowFallbackPolicy.shouldCloseUnusableMainWindow(origin: .windowGroup))
        XCTAssertTrue(MainWindowFallbackPolicy.shouldCloseUnusableMainWindow(origin: .legacyTitleMatch))
        XCTAssertTrue(MainWindowFallbackPolicy.shouldCloseUnusableMainWindow(origin: .fallback))
    }

    func testTitleOnlyWindowIsLegacyMatchNotPrimaryMainConsole() {
        XCTAssertEqual(MainWindowFallbackPolicy.origin(identifier: "main-console-AppWindow-1", title: "LiveSwitcher"), .windowGroup)
        XCTAssertEqual(MainWindowFallbackPolicy.origin(identifier: "main-console-fallback", title: "LiveSwitcher"), .fallback)
        XCTAssertEqual(MainWindowFallbackPolicy.origin(identifier: nil, title: "LiveSwitcher"), .legacyTitleMatch)
        XCTAssertNil(MainWindowFallbackPolicy.origin(identifier: nil, title: "Other Window"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
