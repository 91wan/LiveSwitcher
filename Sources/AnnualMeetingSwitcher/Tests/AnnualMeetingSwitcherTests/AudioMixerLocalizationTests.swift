import XCTest
@testable import LiveSwitcher

final class AudioMixerLocalizationTests: XCTestCase {
    func testMixerFaderAccentModelExposesThreeDistinctSemanticTokens() {
        XCTAssertEqual(AudioMixerFaderAccent.master.rawValue, "action.primary")
        XCTAssertEqual(AudioMixerFaderAccent.media.rawValue, "tone.warn")
        XCTAssertEqual(AudioMixerFaderAccent.bgm.rawValue, "tone.ready")
        XCTAssertEqual(Set(AudioMixerFaderAccent.allCases.map(\.rawValue)).count, 3)
    }

    func testMixerFaderCardsExposeThreeDistinctSemanticAccentStripes() throws {
        let view = try String(contentsOf: sourceURL("Views/AudioMixerView.swift"), encoding: .utf8)

        XCTAssertTrue(view.contains("accentStripe("), "Mixer fader cards should expose a visible semantic left accent stripe.")
        XCTAssertTrue(view.contains("AudioMixerFaderAccent.master.color"))
        XCTAssertTrue(view.contains("AudioMixerFaderAccent.media.color"))
        XCTAssertTrue(view.contains("AudioMixerFaderAccent.bgm.color"))
    }

    func testAudioMixerFaderAccentModelDefinesDistinctTokens() throws {
        let model = try String(contentsOf: sourceURL("Models/AudioMixerPageModel.swift"), encoding: .utf8)

        XCTAssertTrue(model.contains("enum AudioMixerFaderAccent"))
        XCTAssertTrue(model.contains("case master"))
        XCTAssertTrue(model.contains("case media"))
        XCTAssertTrue(model.contains("case bgm"))
        XCTAssertTrue(model.contains("\"action.primary\""))
        XCTAssertTrue(model.contains("\"tone.warn\""))
        XCTAssertTrue(model.contains("\"tone.ready\""))
    }

    func testAudioStrategyUsesStableLocalizedDisplayKeys() throws {
        let strategy = try String(contentsOf: sourceURL("Models/AudioStrategy.swift"), encoding: .utf8)

        XCTAssertTrue(strategy.contains("var displayTitleKey: String"))
        XCTAssertTrue(strategy.contains("NSLocalizedString(displayTitleKey"))
        XCTAssertTrue(strategy.contains("audio.strategy.followProgram.title"))
        XCTAssertTrue(strategy.contains("audio.strategy.followSource.title"))
        XCTAssertTrue(strategy.contains("audio.strategy.bgmOnly.title"))
        XCTAssertTrue(strategy.contains("audio.strategy.mixed.title"))
        XCTAssertFalse(strategy.contains("return \"音频跟随\""))
        XCTAssertFalse(strategy.contains("return \"跟随源\""))
        XCTAssertFalse(strategy.contains("return \"仅 BGM\""))
        XCTAssertFalse(strategy.contains("return \"混合\""))
    }

    func testAudioStrategyLocalizationResourcesExistForEnglishAndChinese() throws {
        let english = try String(contentsOf: sourceURL("Resources/en.lproj/Localizable.strings"), encoding: .utf8)
        let chinese = try String(contentsOf: sourceURL("Resources/zh-Hans.lproj/Localizable.strings"), encoding: .utf8)

        for key in [
            "audio.strategy.followProgram.title",
            "audio.strategy.followSource.title",
            "audio.strategy.bgmOnly.title",
            "audio.strategy.mixed.title"
        ] {
            XCTAssertTrue(english.contains("\"\(key)\""))
            XCTAssertTrue(chinese.contains("\"\(key)\""))
        }

        XCTAssertTrue(english.contains("\"Follow program\""))
        XCTAssertTrue(english.contains("\"Follow source\""))
        XCTAssertTrue(english.contains("\"BGM only\""))
        XCTAssertTrue(english.contains("\"Mixed\""))
        XCTAssertTrue(chinese.contains("\"音频跟随\""))
        XCTAssertTrue(chinese.contains("\"跟随源\""))
        XCTAssertTrue(chinese.contains("\"仅 BGM\""))
        XCTAssertTrue(chinese.contains("\"混合\""))
    }

    func testSwiftPackagesProcessLocalizationResources() throws {
        let rootPackage = try String(contentsOf: repositoryURL("Package.swift"), encoding: .utf8)
        let appPackage = try String(contentsOf: repositoryURL("Sources/AnnualMeetingSwitcher/Package.swift"), encoding: .utf8)

        for manifest in [rootPackage, appPackage] {
            XCTAssertTrue(manifest.contains("defaultLocalization: \"en\""))
            XCTAssertTrue(manifest.contains(".process(\"Resources\")"))
        }
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        try sourceRoot().appendingPathComponent(relativePath)
    }

    private func sourceRoot() throws -> URL {
        try repositoryURL("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
    }

    private func repositoryURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
