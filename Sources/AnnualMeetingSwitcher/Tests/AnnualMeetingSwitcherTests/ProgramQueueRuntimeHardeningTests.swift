import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramQueueRuntimeHardeningTests: XCTestCase {
    func testProgramItemsIsPrivateSet() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("private(set) var programItems"))
    }

    func testProgramQueueFacadeProjectionUsesNarrowApplyMethod() throws {
        let source = try runtimeFacadeSyncSource()

        XCTAssertTrue(source.contains("applyProgramQueueProjectionFromRuntime(runtime.state.program.items)"))
    }

    func testProgramItemsIsNotAssignedOutsideAllowedFacadePaths() throws {
        let offenders = try sourceFilesContaining(#"programItems\s*="#)
            .filter { path, line in
                !path.hasSuffix("ViewModel.swift")
                    && !path.hasSuffix("ViewModel+RuntimeFacadeSync.swift")
                    && !path.hasSuffix("ViewModel+Persistence.swift")
                    && !line.contains("private(set) var programItems")
                    && !line.contains("applyProgramQueueProjectionFromRuntime")
                    && !line.contains("state.programItems")
            }

        XCTAssertTrue(offenders.isEmpty, offenders.map { "\($0.path):\($0.line)" }.joined(separator: "\n"))
    }

    func testProgramItemsIsNotAppendedOutsideRuntimeFacade() throws {
        let source = try programQueueSource()

        XCTAssertFalse(source.contains("programItems.append"))
    }

    func testProgramItemsIsNotRemovedOutsideRuntimeFacade() throws {
        let source = try programQueueSource()

        XCTAssertFalse(source.contains("programItems.remove"))
    }

    func testProgramItemsIsNotMovedOutsideRuntimeFacade() throws {
        let source = try programQueueSource()

        XCTAssertFalse(source.contains("programItems.move"))
    }

    func testProgramQueueOwnedFacadeProjectionStillUpdatesUIList() {
        let item = ProgramItem(title: "Runtime", subtitle: "MEDIA")
        let viewModel = makeViewModel()

        viewModel.applyProgramQueueProjectionFromRuntime([item])

        XCTAssertEqual(viewModel.programItems, [item])
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ProgramQueueRuntimeHardeningTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func runtimeFacadeSyncSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacadeSync.swift")
    }

    private func programQueueSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift")
    }

    private func sourceFilesContaining(_ pattern: String) throws -> [(path: String, line: String)] {
        let root = try repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        let urls = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        )?.compactMap { $0 as? URL } ?? []
        let regex = try NSRegularExpression(pattern: pattern)
        var matches: [(path: String, line: String)] = []
        for url in urls where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for line in text.components(separatedBy: .newlines) {
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                if regex.firstMatch(in: line, range: range) != nil {
                    matches.append((url.lastPathComponent, line))
                }
            }
        }
        return matches
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
