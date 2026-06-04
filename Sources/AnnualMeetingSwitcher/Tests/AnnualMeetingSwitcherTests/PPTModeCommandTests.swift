import XCTest
@testable import LiveSwitcher

final class PPTModeCommandTests: XCTestCase {
    func testPPTModeToggleModelFlipsTheCurrentState() {
        XCTAssertTrue(PPTModeToggleModel.nextState(isEnabled: false))
        XCTAssertFalse(PPTModeToggleModel.nextState(isEnabled: true))
    }

    func testCommandPathUsesTogglePPTMode() throws {
        let app = try sourceText("App.swift")

        XCTAssertTrue(app.contains("viewModel.togglePPTMode(source: .command)"))
        XCTAssertFalse(app.contains("viewModel.isPageInterceptEnabled.toggle()"))
    }

    @MainActor
    func testCommandPathRecordsSourceCommandAfterRuntimeSuccess() throws {
        let suiteName = "PPTModeCommandTests.source.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .command)

        let event = try XCTUnwrap(viewModel.supportEvents.last(where: { $0.kind == .pptModeChanged }))
        XCTAssertTrue(event.detail.contains("isOn=true"))
        XCTAssertTrue(event.detail.contains("source=command"))
    }

    func testCommandPathDoesNotDirectlyMutatePPTBool() throws {
        let app = try sourceText("App.swift")

        XCTAssertFalse(app.contains("isPageInterceptEnabled ="))
        XCTAssertFalse(app.contains("isPageInterceptEnabled.toggle()"))
    }

    @MainActor
    func testDuplicatePPTModeSetDoesNotRecordRepeatedEvent() throws {
        let suiteName = "PPTModeCommandTests.duplicate.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(false, source: .liveMode)
        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pptModeChanged })
    }

    func testToolbarUsesModeAwarePPTSourceInsteadOfDirectStateMutation() throws {
        let toolbar = try sourceText("Views/MainToolbar.swift")

        XCTAssertTrue(toolbar.contains("pptModeToggleSource"))
        XCTAssertTrue(toolbar.contains("viewModel.togglePPTMode(source: pptModeToggleSource)"))
        XCTAssertFalse(toolbar.contains("viewModel.isPageInterceptEnabled.toggle()"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
