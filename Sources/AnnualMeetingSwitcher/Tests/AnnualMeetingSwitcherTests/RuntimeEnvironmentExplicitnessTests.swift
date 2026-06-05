import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeEnvironmentExplicitnessTests: XCTestCase {
    func testLiveRuntimeStoreDefaultIsAudioOwned() {
        XCTAssertEqual(LiveRuntimeStore().bridgeMode, .audioOwned)
    }

    func testProductionViewModelRuntimeIsAutomationCommandOwning() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .automationCommandOwned)
    }

    func testFullRuntimeMustBeExplicitInTests() {
        XCTAssertEqual(LiveRuntimeEnvironment.fullRuntimeForTests().bridgeMode, .fullRuntime)
        XCTAssertEqual(LiveRuntimeEnvironment.productionAudioOwned().bridgeMode, .audioOwned)
        XCTAssertEqual(LiveRuntimeEnvironment.productionBGMOwning().bridgeMode, .bgmOwned)
        XCTAssertEqual(LiveRuntimeEnvironment.productionProjectionOwned().bridgeMode, .projectionOwned)
        XCTAssertEqual(LiveRuntimeEnvironment.productionPPTOwning().bridgeMode, .pptOwned)
        XCTAssertEqual(LiveRuntimeEnvironment.productionAutomationNoticeOwning().bridgeMode, .automationNoticeOwned)
        XCTAssertEqual(LiveRuntimeEnvironment.productionSupportOwning().bridgeMode, .supportOwned)
        XCTAssertEqual(LiveRuntimeEnvironment.productionAutomationCommandOwning().bridgeMode, .automationCommandOwned)
        XCTAssertEqual(LiveRuntimeEnvironment.recordingOnlyForTests().bridgeMode, .recordingOnly)
    }

    func testNoImplicitLiveRuntimeEnvironmentDefaultInTests() throws {
        let violations = try testSourceLines { line in
            line.contains("LiveRuntimeEnvironment()")
                || (line.contains("LiveRuntimeEnvironment(")
                    && !line.contains("bridgeMode:")
                    && !line.contains(".productionAudioOwned(")
                    && !line.contains(".productionMediaOwned(")
                    && !line.contains(".productionBGMOwning(")
                    && !line.contains(".productionProjectionOwned(")
                    && !line.contains(".productionPPTOwning(")
                    && !line.contains(".productionAutomationNoticeOwning(")
                    && !line.contains(".productionSupportOwning(")
                    && !line.contains(".productionAutomationCommandOwning(")
                    && !line.contains(".fullRuntimeForTests(")
                    && !line.contains(".recordingOnlyForTests("))
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testNoImplicitFullRuntimeStoreCreationInTests() throws {
        let violations = try storeConstructionsWithImplicitEnvironment()

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testCustomEffectRunnerStoreCreationRequiresEnvironment() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeStore.swift")

        XCTAssertTrue(source.contains("effectRunner: LiveRuntimeEffectRunner,"))
        XCTAssertTrue(source.contains("environment: LiveRuntimeEnvironment"))
        XCTAssertFalse(source.contains("effectRunner: LiveRuntimeEffectRunner ="))
        XCTAssertFalse(source.contains("environment: LiveRuntimeEnvironment?"))
    }

    func testPersistencePortDoesNotChangeBridgeModeAutomatically() {
        let runner = LiveRuntimeEffectRunner(
            recordsOnly: false,
            persistence: RuntimeEnvironmentExplicitnessPersistencePort()
        )
        let store = LiveRuntimeStore(
            effectRunner: runner,
            environment: .productionAudioOwned()
        )

        XCTAssertEqual(store.connectedPortKinds, [.persistence])
        XCTAssertEqual(store.bridgeMode, .audioOwned)
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
            .filter {
                $0.lastPathComponent != "RuntimeEnvironmentExplicitnessTests.swift"
                    && $0.lastPathComponent != "RuntimeStoreInitializationTests.swift"
            }
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

    private func storeConstructionsWithImplicitEnvironment() throws -> [String] {
        try testSourceURLs()
            .filter {
                $0.lastPathComponent != "RuntimeEnvironmentExplicitnessTests.swift"
                    && $0.lastPathComponent != "RuntimeStoreInitializationTests.swift"
            }
            .flatMap { url -> [String] in
                let text = try String(contentsOf: url, encoding: .utf8)
                return storeConstructionRanges(in: text)
                    .filter { range in
                        let construction = String(text[range])
                        return construction.contains("effectRunner:")
                            && !construction.contains("environment:")
                    }
                    .map { range in
                        "\(url.lastPathComponent):\(lineNumber(for: range.lowerBound, in: text)): missing explicit environment"
                    }
            }
    }

    private func storeConstructionRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex
        while let start = text.range(of: "LiveRuntimeStore(", range: searchStart..<text.endIndex)?.lowerBound {
            var index = start
            var depth = 0
            var hasSeenOpeningParenthesis = false
            while index < text.endIndex {
                let character = text[index]
                if character == "(" {
                    depth += 1
                    hasSeenOpeningParenthesis = true
                } else if character == ")" {
                    depth -= 1
                    if hasSeenOpeningParenthesis && depth == 0 {
                        let end = text.index(after: index)
                        ranges.append(start..<end)
                        searchStart = end
                        break
                    }
                }
                index = text.index(after: index)
            }
            if index == text.endIndex {
                break
            }
        }
        return ranges
    }

    private func lineNumber(for index: String.Index, in text: String) -> Int {
        text[..<index].reduce(1) { count, character in
            character == "\n" ? count + 1 : count
        }
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

private final class RuntimeEnvironmentExplicitnessPersistencePort: PersistencePort {
    func save() {}
}
