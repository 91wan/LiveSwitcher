import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeEnvironmentExplicitnessTests: XCTestCase {
    func testLiveRuntimeStoreDefaultIsAudioOwned() {
        XCTAssertEqual(LiveRuntimeStore().bridgeMode, .audioOwned)
    }

    func testProductionViewModelRuntimeIsMediaOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .mediaOwned)
    }

    func testFullRuntimeMustBeExplicitInTests() {
        XCTAssertEqual(LiveRuntimeEnvironment.fullRuntimeForTests().bridgeMode, .fullRuntime)
        XCTAssertEqual(LiveRuntimeEnvironment.productionAudioOwned().bridgeMode, .audioOwned)
        XCTAssertEqual(LiveRuntimeEnvironment.recordingOnlyForTests().bridgeMode, .recordingOnly)
    }

    func testNoImplicitLiveRuntimeEnvironmentDefaultInTests() throws {
        let violations = try testSourceLines { line in
            line.contains("LiveRuntimeEnvironment()")
                || (line.contains("LiveRuntimeEnvironment(")
                    && !line.contains("bridgeMode:")
                    && !line.contains(".productionAudioOwned(")
                    && !line.contains(".productionMediaOwned(")
                    && !line.contains(".fullRuntimeForTests(")
                    && !line.contains(".recordingOnlyForTests("))
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testNoImplicitFullRuntimeStoreCreationInTests() throws {
        let violations = try testSourceLines { line in
            line.contains("LiveRuntimeStore()")
                || (line.contains("LiveRuntimeStore(")
                    && line.contains("effectRunner:")
                    && !line.contains("environment:")
                    && !line.contains("RuntimeTestFactory."))
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testReducerCallsInTestsUseExplicitEnvironment() throws {
        let runtimeState = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        XCTAssertFalse(runtimeState.contains("environment: LiveRuntimeEnvironment ="))
    }

    func testRuntimeStoreInTestsUsesFactoryOrExplicitEnvironment() throws {
        let store = RuntimeTestFactory.fullRuntimeStore()

        XCTAssertEqual(store.bridgeMode, .fullRuntime)
    }

    func testInjectedFullRuntimeIsOnlyUsedWhenExplicit() {
        let runtime = RuntimeTestFactory.fullRuntimeStore()
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )

        XCTAssertEqual(viewModel.runtimeBridgeMode, .fullRuntime)
        XCTAssertTrue(viewModel.runtime === runtime)
    }

    private func testSourceLines(matching predicate: (String) -> Bool) throws -> [String] {
        try testSourceURLs()
            .filter { $0.lastPathComponent != "RuntimeEnvironmentExplicitnessTests.swift" }
            .flatMap { url -> [String] in
                let text = try String(contentsOf: url, encoding: .utf8)
                return text
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .enumerated()
                    .compactMap { index, line in
                        let lineText = String(line)
                        guard predicate(lineText) else { return nil }
                        return "\(url.lastPathComponent):\(index + 1): \(lineText.trimmingCharacters(in: .whitespaces))"
                    }
            }
    }

    private func testSourceURLs() throws -> [URL] {
        let testsRoot = try repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests")
        return try FileManager.default.contentsOfDirectory(
            at: testsRoot,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "swift" }
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
