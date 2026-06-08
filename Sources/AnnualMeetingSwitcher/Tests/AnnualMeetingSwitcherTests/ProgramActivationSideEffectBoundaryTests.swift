import XCTest
@testable import LiveSwitcher

final class ProgramActivationSideEffectBoundaryTests: XCTestCase {
    func testProgramActivationSideEffectHandlersStructExists() throws {
        let source = try repositorySource(programActivationSideEffectHandlersPath)

        XCTAssertTrue(source.contains("struct ProgramActivationSideEffectHandlers"))
    }

    func testProgramActivationSideEffectHandlersOnlyContainsActivationSideEffects() throws {
        let source = try repositorySource(programActivationSideEffectHandlersPath)

        XCTAssertTrue(source.contains("presentKeynote"))
        XCTAssertTrue(source.contains("openPPTX"))
        XCTAssertTrue(source.contains("stopDeck"))
        XCTAssertTrue(source.contains("presentActiveDeck"))
        XCTAssertTrue(source.contains("presentInvalidDeckAlert"))
        XCTAssertFalse(source.contains("programSeekToStart"))
        XCTAssertFalse(source.contains("programRestartFromBeginning"))
        XCTAssertFalse(source.contains("programSeekToEnd"))
    }

    func testSwitcherViewModelActionHandlersIsRemoved() throws {
        let productionSources = try productionSourceFiles()
        let offenders = productionSources.filter { _, source in
            source.contains("struct SwitcherViewModelActionHandlers")
        }

        XCTAssertTrue(offenders.isEmpty, offenders.keys.sorted().joined(separator: "\n"))
    }

    func testViewModelUsesProgramActivationSideEffectsProperty() throws {
        let source = try repositorySource(viewModelPath)

        XCTAssertTrue(source.contains("@ObservationIgnored var programActivationSideEffects = ProgramActivationSideEffectHandlers()"))
    }

    func testViewModelDoesNotExposeGenericActionHandlersProperty() throws {
        let source = try repositorySource(viewModelPath)

        XCTAssertFalse(source.contains("var actionHandlers"))
        XCTAssertFalse(source.contains("SwitcherViewModelActionHandlers"))
    }

    func testActivationSideEffectHandlersDoNotContainMediaSeekHandlers() throws {
        let productionSources = try productionSourceFiles()
        let forbidden = [
            "programSeekToStart",
            "programRestartFromBeginning",
            "programSeekToEnd"
        ]
        let offenders = productionSources.filter { path, source in
            !path.hasSuffix("AVPlayerCoordinator.swift")
                && forbidden.contains { source.contains($0) }
        }

        XCTAssertTrue(offenders.isEmpty, offenders.keys.sorted().joined(separator: "\n"))
    }

    func testActivationSideEffectHandlersDoNotContainProgramRestartHandler() throws {
        let source = try repositorySource(programActivationSideEffectHandlersPath)

        XCTAssertFalse(source.contains("programRestartFromBeginning"))
        XCTAssertFalse(source.contains("restartFromBeginning"))
    }

    private var programActivationSideEffectHandlersPath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ProgramActivationSideEffectHandlers.swift"
    }

    private var viewModelPath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift"
    }

    private func productionSourceFiles() throws -> [String: String] {
        let root = try repositoryRoot()
        let sourceRoot = root.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        guard let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        ) else { return [:] }

        var sources: [String: String] = [:]
        for entry in enumerator {
            guard let url = entry as? URL,
                  url.pathExtension == "swift"
            else { continue }
            let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")
            sources[relativePath] = try repositorySource(relativePath)
        }
        return sources
    }
}
