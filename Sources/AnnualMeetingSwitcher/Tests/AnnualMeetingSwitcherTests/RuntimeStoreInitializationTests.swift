import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeStoreInitializationTests: XCTestCase {
    func testDefaultStoreIsRecordingAudioOwned() {
        let store = LiveRuntimeStore()

        XCTAssertEqual(store.bridgeMode, .audioOwned)
        XCTAssertTrue(store.connectedPortKinds.isEmpty)
    }

    func testStoreWithCustomEffectRunnerRequiresExplicitEnvironment() throws {
        let source = try liveRuntimeStoreSource()

        XCTAssertTrue(source.contains("effectRunner: LiveRuntimeEffectRunner,"))
        XCTAssertTrue(source.contains("environment: LiveRuntimeEnvironment"))
        XCTAssertFalse(source.contains("effectRunner: LiveRuntimeEffectRunner ="))
    }

    func testStoreWithPersistencePortDoesNotInferBGMOwning() {
        let runner = LiveRuntimeEffectRunner(
            recordsOnly: false,
            persistence: RuntimeStoreInitializationPersistencePort()
        )
        let store = LiveRuntimeStore(
            effectRunner: runner,
            environment: .productionAudioOwned()
        )

        XCTAssertEqual(store.connectedPortKinds, [.persistence])
        XCTAssertEqual(store.bridgeMode, .audioOwned)
    }

    func testNoDefaultEnvironmentForCustomEffectRunner() throws {
        let source = try liveRuntimeStoreSource()

        XCTAssertFalse(source.contains("environment: LiveRuntimeEnvironment? = nil"))
    }

    func testNoDefaultEnvironmentFunctionExists() throws {
        let source = try liveRuntimeStoreSource()

        XCTAssertFalse(source.contains("defaultEnvironment(for:"))
        XCTAssertFalse(source.contains("connectedPortKinds.contains(.persistence)"))
    }

    func testProductionViewModelPassesAutomationCommandOwningExplicitly() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertTrue(source.contains("environment: .productionProgramActivationOwning()"))
    }

    private func liveRuntimeStoreSource() throws -> String {
        try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeStore.swift")
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}

private final class RuntimeStoreInitializationPersistencePort: PersistencePort {
    func save() {}
    func saveConsoleMode(_ mode: ConsoleMode) {}
    func saveThemeOverride(_ theme: ThemeOverride) {}
    func saveAudioStrategy(_ strategy: AudioStrategy) {}
    func saveSpeakerMode(_ isEnabled: Bool) {}
    func saveBGMPlayMode(_ playMode: BGMPlayMode) {}
    func saveAutoPlayNextVideoOnEnd(_ isEnabled: Bool) {}
    func saveAutoAdvanceAtScheduledTime(_ isEnabled: Bool) {}
    func saveShowAgendaTimeline(_ isEnabled: Bool) {}
    func saveCornerLogoPosition(_ position: CornerLogoPosition) {}
}
