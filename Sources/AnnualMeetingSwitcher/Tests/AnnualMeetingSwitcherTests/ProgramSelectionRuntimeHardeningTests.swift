import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramSelectionRuntimeHardeningTests: XCTestCase {
    private let removedCompatibilityCall = "." + "facadeCurrentProgramChanged("

    func testCurrentProgramItemHasNoDidSetRuntimeDispatch() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let currentProgramItemDeclaration = source.components(separatedBy: "\n")
            .first { $0.contains("currentProgramItem") && $0.contains("var") } ?? ""

        XCTAssertFalse(currentProgramItemDeclaration.contains("didSet"))
        XCTAssertFalse(source.contains("currentProgramItem") && source.contains(removedCompatibilityCall))
    }

    func testSwitchToProgramDoesNotDispatchFacadeCurrentProgramChanged() throws {
        let body = try programActivationSource().extractedRuntimeFunctionBody(named: "switchToProgram")

        XCTAssertNotNil(body)
        XCTAssertFalse(body?.contains(removedCompatibilityCall) == true)
    }

    func testExecuteProgramActivationPlanFromRuntimeDoesNotDispatchFacadeCurrentProgramChanged() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift"
        )
        let body = source.extractedRuntimeFunctionBody(named: "executeProgramActivationPlanFromRuntime")

        XCTAssertNotNil(body)
        XCTAssertFalse(source.contains(removedCompatibilityCall))
        XCTAssertTrue(source.contains("context.dispatch(.operatorSelectedProgram"))
    }

    func testClearCurrentProgramSelectionDoesNotDispatchFacadeCurrentProgramChanged() throws {
        let body = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramSelection.swift"
        ).extractedRuntimeFunctionBody(named: "clearCurrentProgramSelection")

        XCTAssertNotNil(body)
        XCTAssertFalse(body?.contains(removedCompatibilityCall) == true)
        XCTAssertTrue(body?.contains(".operatorClearedCurrentProgram(reason: reason)") == true)
    }

    func testMediaPlaybackClearPathsDoNotDispatchFacadeCurrentProgramChanged() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+MediaPlayback.swift"
        )

        XCTAssertFalse(source.contains(removedCompatibilityCall))
        XCTAssertTrue(source.contains("clearCurrentProgramSelection(reason: .htmlPresentationEnded)"))
        XCTAssertTrue(source.contains("clearCurrentProgramSelection(reason: .mediaPlaybackEnded)"))
    }

    func testNoViewModelSourceDispatchesFacadeCurrentProgramChanged() throws {
        let productionSources = try productionViewModelSources()
        let offenders = productionSources.filter { path, source in
            source.contains(removedCompatibilityCall)
                && !path.contains("ViewModel+RuntimeFacade")
        }

        XCTAssertTrue(offenders.isEmpty, offenders.keys.sorted().joined(separator: "\n"))
    }

    private func programActivationSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift")
    }

    private func productionViewModelSources() throws -> [String: String] {
        let root = try repositoryRoot()
        let sourceRoot = root.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        guard let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        ) else { return [:] }

        var sources: [String: String] = [:]
        for entry in enumerator {
            guard let url = entry as? URL,
                  url.lastPathComponent.hasPrefix("ViewModel"),
                  url.pathExtension == "swift"
            else { continue }
            let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")
            sources[relativePath] = try repositorySource(relativePath)
        }
        return sources
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
