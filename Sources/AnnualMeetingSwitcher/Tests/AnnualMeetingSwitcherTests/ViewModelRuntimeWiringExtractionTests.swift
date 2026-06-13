import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelRuntimeWiringExtractionTests: XCTestCase {
    func testSwitcherRuntimePortBundleCreatesAllProductionPorts() {
        let ports = SwitcherRuntimePortBundle()

        XCTAssertNotNil(ports.mediaPlaybackPort)
        XCTAssertNotNil(ports.bgmPlaybackPort)
        XCTAssertNotNil(ports.bgmTimerPort)
        XCTAssertNotNil(ports.projectionPort)
        XCTAssertNotNil(ports.pptPort)
        XCTAssertNotNil(ports.automationNoticePort)
        XCTAssertNotNil(ports.supportPort)
        XCTAssertNotNil(ports.automationPort)
        XCTAssertNotNil(ports.presentationQueryPort)
        XCTAssertNotNil(ports.programActivationPort)
        XCTAssertNotNil(ports.audioRoutingPort)
        XCTAssertNotNil(ports.imageAssetPort)
        XCTAssertNotNil(ports.persistencePort)
    }

    func testSwitcherRuntimePortBundleEffectRunnerReportsExpectedPorts() {
        let runner = SwitcherRuntimePortBundle().makeEffectRunner()

        XCTAssertEqual(
            runner.connectedPortKinds,
            [.media, .bgm, .bgmTimer, .projection, .ppt, .automation, .automationNotice, .support, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testProductionConnectedPortsIncludeProgramActivationSet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(
            viewModel.runtimeConnectedPortKinds,
            [.media, .bgm, .bgmTimer, .projection, .ppt, .automation, .automationNotice, .support, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]
        )
    }

    func testProductionBridgeModeIsProgramActivationOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .programActivationOwned)
    }

    func testViewModelInitDoesNotContainRuntimePortHandlerAssignments() throws {
        let initializer = try switcherViewModelInitializer()

        for forbidden in [
            ".loadHandler =",
            ".playHandler =",
            ".startHandler =",
            ".recordHandler =",
            ".runHandler =",
            ".saveHandler =",
            "mediaPlaybackPort.loadHandler =",
            "bgmPlaybackPort.prepareHandler =",
            "automationPort.runHandler =",
            "persistencePort.saveHandler ="
        ] {
            XCTAssertFalse(initializer.contains(forbidden), forbidden)
        }
    }

    func testViewModelInitDoesNotGrowRuntimePortWiringBlock() throws {
        let initializer = try switcherViewModelInitializer()

        XCTAssertFalse(initializer.contains("mediaPlaybackPort.loadHandler ="))
        XCTAssertFalse(initializer.contains("bgmPlaybackPort.prepareHandler ="))
        XCTAssertFalse(initializer.contains("automationPort.runHandler ="))
        XCTAssertFalse(initializer.contains("persistencePort.saveHandler ="))
    }

    func testViewModelInitUsesSwitcherRuntimePortBundle() throws {
        let initializer = try switcherViewModelInitializer()

        XCTAssertTrue(initializer.contains("let runtimePorts = SwitcherRuntimePortBundle()"))
        XCTAssertTrue(initializer.contains("runtimePorts.makeEffectRunner()"))
    }

    func testViewModelInitCallsConfigureRuntimePortHandlers() throws {
        let initializer = try switcherViewModelInitializer()

        XCTAssertTrue(initializer.contains("configureRuntimePortHandlers(runtimePorts)"))
    }

    func testRuntimePortHandlerAssignmentsLiveInRuntimeWiringFile() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeWiring.swift")

        XCTAssertTrue(source.contains("func configureRuntimePortHandlers(_ ports: SwitcherRuntimePortBundle)"))
        XCTAssertTrue(source.contains("ports.mediaPlaybackPort.loadHandler ="))
        XCTAssertTrue(source.contains("ports.bgmPlaybackPort.prepareHandler ="))
        XCTAssertTrue(source.contains("ports.automationPort.runHandler ="))
        XCTAssertTrue(source.contains("ports.programActivationPort.executeHandler ="))
        XCTAssertTrue(source.contains("ports.persistencePort.saveHandler ="))
    }

    func testRuntimeWiringFileDoesNotLiveInRuntimeCoreFolder() throws {
        let runtimeWiring = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeWiring.swift")
        let runtimeFolderFiles = try runtimeSourceFileNames()

        XCTAssertTrue(runtimeWiring.contains("extension SwitcherViewModel"))
        XCTAssertFalse(runtimeFolderFiles.contains("ViewModel+RuntimeWiring.swift"))
    }

    private func switcherViewModelInitializer() throws -> String {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        return try XCTUnwrap(source.initializerBody(containing: "runtime: LiveRuntimeStore? = nil"))
    }

    private func runtimeSourceFileNames() throws -> Set<String> {
        let runtimeURL = try repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime")
        let urls = try FileManager.default.contentsOfDirectory(
            at: runtimeURL,
            includingPropertiesForKeys: nil
        )
        return Set(urls.map(\.lastPathComponent))
    }

    private func repositorySource(_ relativePath: String) throws -> String {
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

private extension String {
    func initializerBody(containing marker: String) -> String? {
        guard let markerRange = range(of: marker) else { return nil }
        var search = markerRange.upperBound
        while search < endIndex {
            if self[search] == "{" {
                return balancedBody(startingAt: search)
            }
            search = index(after: search)
        }
        return nil
    }

    func balancedBody(startingAt openingBrace: String.Index) -> String? {
        var depth = 0
        var index = openingBrace
        while index < endIndex {
            if self[index] == "{" {
                depth += 1
            } else if self[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}
