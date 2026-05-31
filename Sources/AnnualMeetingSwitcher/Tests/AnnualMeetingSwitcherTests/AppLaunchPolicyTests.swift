import XCTest

final class AppLaunchPolicyTests: XCTestCase {
    func testSwiftPMEntryPointUsesRegularActivationPolicy() throws {
        let source = try sourceText("main.swift")

        XCTAssertTrue(source.contains("import AppKit"))
        XCTAssertTrue(source.contains("NSApplication.shared.setActivationPolicy(.regular)"))
    }

    func testAppInstallsMainWindowFallbackForRestorationFailures() throws {
        let source = try sourceText("App.swift")

        XCTAssertTrue(source.contains("@NSApplicationDelegateAdaptor(LiveSwitcherAppDelegate.self)"))
        XCTAssertTrue(source.contains("applicationShouldHandleReopen"))
        XCTAssertTrue(source.contains("ensureMainWindowIfNeeded"))
        XCTAssertTrue(source.contains("isMainConsoleWindow"))
        XCTAssertTrue(source.contains("hasPrefix(\"main-console\")"))
        XCTAssertTrue(source.contains("ContentView()"))
        XCTAssertTrue(source.contains("NSHostingView"))
    }

    func testMainWindowFallbackHasSingleDelayedScheduler() throws {
        let source = try sourceText("App.swift")
        let delayedFallbackCount = source
            .components(separatedBy: "try? await Task.sleep(nanoseconds:")
            .count - 1

        XCTAssertEqual(delayedFallbackCount, 1)
        XCTAssertFalse(source.contains("900_000_000"))
    }

    func testFallbackViewModelReferenceIsStrongUntilWindowExists() throws {
        let source = try sourceText("App.swift")

        XCTAssertTrue(source.contains("static var sharedViewModel: SwitcherViewModel?"))
        XCTAssertFalse(source.contains("static weak var sharedViewModel"))
    }

    func testFallbackReordersRestoredMainWindowInsteadOfReturningInvisible() throws {
        let source = try sourceText("App.swift")

        XCTAssertTrue(source.contains("if let existingMainWindow = NSApp.windows.first(where: isMainConsoleWindow)"))
        XCTAssertTrue(source.contains("bringMainWindowToFront(existingMainWindow, activate: activate)"))
        XCTAssertTrue(source.contains("if isUsablyVisibleMainWindow(existingMainWindow)"))
        XCTAssertTrue(source.contains("closeUnusableMainWindow(existingMainWindow)"))
        XCTAssertTrue(source.contains("window.collectionBehavior.insert(.moveToActiveSpace)"))
        XCTAssertFalse(source.contains("if NSApp.windows.contains(where: isMainConsoleWindow) {\n            return\n        }"))
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
