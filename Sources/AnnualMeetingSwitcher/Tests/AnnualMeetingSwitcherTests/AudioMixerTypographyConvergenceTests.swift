import XCTest

final class AudioMixerTypographyConvergenceTests: XCTestCase {
    func testAudioMixerViewUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        let source = try String(contentsOf: sourceURL("Views/AudioMixerView.swift"), encoding: .utf8)

        XCTAssertFalse(
            source.contains(".font(.system(size:"),
            "AudioMixerView.swift should use StudioTheme.TypeScale instead of raw font sizes."
        )
        XCTAssertTrue(
            source.contains("StudioTheme.TypeScale"),
            "AudioMixerView.swift should reference the shared type scale."
        )
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
