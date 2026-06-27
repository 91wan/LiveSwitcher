import XCTest
@testable import LiveSwitcher

final class ProgramTransitionPruningTests: XCTestCase {
    func testFakeProgramTransitionControlsAndStateAreRemoved() throws {
        let viewModel = try sourceText("ViewModel.swift")
        let monitor = try sourceText("Views/ProgramMonitorView.swift")
        let mixer = try sourceText("Views/AudioMixerView.swift")

        XCTAssertFalse(viewModel.contains("crossfadeDuration"))
        XCTAssertFalse(viewModel.contains("转场配置"))
        XCTAssertFalse(monitor.contains("transitionControlCard"))
        XCTAssertFalse(monitor.contains("ProgramTransitionControlModel"))
        XCTAssertFalse(monitor.contains("crossfadeDuration"))
        XCTAssertFalse(monitor.contains(".animation(.easeInOut(duration: viewModel.crossfadeDuration)"))
        XCTAssertFalse(mixer.contains("transitionCard"))
        XCTAssertFalse(mixer.contains("ProgramTransitionControlModel"))
        XCTAssertFalse(mixer.contains("crossfadeDuration"))
    }

    func testDeletedProgramTransitionControlModelHasNoSourceFile() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: try sourcePath("Models/ProgramTransitionControlModel.swift")))
    }

    func testProgramOutputTransitionRFCExistsAndCoversHardwareRisks() throws {
        let rfc = try repositoryText("docs/architecture/program-output-transition-rfc.md")

        XCTAssertTrue(rfc.contains("双播放器 A/B 真交叉溶解"))
        XCTAssertTrue(rfc.contains("淡出到壁纸"))
        XCTAssertTrue(rfc.contains("首帧就绪"))
        XCTAssertTrue(rfc.contains("超时"))
        XCTAssertTrue(rfc.contains("generation token"))
        XCTAssertTrue(rfc.contains("Panic/FTB 抢占"))
        XCTAssertTrue(rfc.contains("音频"))
        XCTAssertTrue(rfc.contains("1080p"))
        XCTAssertTrue(rfc.contains("4K"))
        XCTAssertTrue(rfc.contains("硬件验收矩阵"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
    }

    private func sourcePath(_ relativePath: String) throws -> String {
        try sourceRoot().appendingPathComponent(relativePath).path
    }

    private func sourceRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate package source root from test source path.")
    }

    private func repositoryText(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
