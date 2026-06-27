import AppKit
import AVFoundation
import XCTest
@testable import LiveSwitcher

final class ThumbnailServiceTests: XCTestCase {
    func testDefaultCacheDirectoryLivesInLiveSwitcherThumbnailCache() {
        let path = ThumbnailService.defaultCacheDirectory.path

        XCTAssertTrue(path.contains("/Caches/"))
        XCTAssertTrue(path.hasSuffix("LiveSwitcher/thumbnails"))
    }

    func testCacheKeyChangesWhenFileModificationDateChanges() {
        let url = URL(fileURLWithPath: "/tmp/Opening Final.mp4")
        let size = CGSize(width: 96, height: 54)
        let first = ThumbnailService.cacheKey(
            for: url,
            kind: .media,
            targetSize: size,
            modificationDate: Date(timeIntervalSince1970: 1_000)
        )
        let second = ThumbnailService.cacheKey(
            for: url,
            kind: .media,
            targetSize: size,
            modificationDate: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertNotEqual(first, second)
        XCTAssertTrue(first.hasSuffix(".png"))
    }

    func testFallbackSymbolsAreDefinedForProgramSourceKinds() {
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .media, isVideo: true), "film")
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .media, isVideo: false), "music.note")
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .html, isVideo: false), "globe")
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .pptx, isVideo: false), "doc.richtext")
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .keynote, isVideo: false), "play.rectangle.fill")
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .activeDeck, isVideo: false), "play.rectangle.fill")
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .unsupported, isVideo: false), "doc.fill")
    }

    func testAudioProgramThumbnailUsesCacheAndInvalidatesOnMTimeChange() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherThumbnailTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let audio = temp.appendingPathComponent("walk-in.mp3")
        try Data("not-real-audio-but-enough-for-placeholder".utf8).write(to: audio)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_000)],
            ofItemAtPath: audio.path
        )

        let service = ThumbnailService(cacheDirectory: temp.appendingPathComponent("thumbs", isDirectory: true))
        let size = CGSize(width: 96, height: 54)
        let firstURL = try await service.cacheFileURL(for: audio, kind: .media, targetSize: size)
        let first = await service.thumbnail(for: audio, kind: .media, targetSize: size)

        XCTAssertNotNil(first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))

        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 2_000)],
            ofItemAtPath: audio.path
        )
        let secondURL = try await service.cacheFileURL(for: audio, kind: .media, targetSize: size)

        XCTAssertNotEqual(firstURL.lastPathComponent, secondURL.lastPathComponent)
    }

    func testAudioWaveformSamplesAreDerivedFromReadableAudioFile() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherWaveformTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let audio = temp.appendingPathComponent("tone.wav")
        try writeSineWaveFixture(to: audio)

        let samples = try ThumbnailService.normalizedAudioSamples(for: audio, sampleCount: 24)

        XCTAssertEqual(samples.count, 24)
        XCTAssertTrue(samples.allSatisfy { $0 >= 0 && $0 <= 1 })
        XCTAssertTrue(samples.contains { $0 > 0.1 })
    }

    func testRunQueueRowsRenderThumbnailViewInsteadOfPlainIconOnlySourceRows() throws {
        let source = try sourceText("Views/RunQueueView.swift")

        XCTAssertTrue(source.contains("ProgramThumbnailView("))
        XCTAssertTrue(source.contains("displaySize: CGSize(width: 48, height: 27)"))
        XCTAssertTrue(source.contains("private let rowContentIndent"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
    }

    private func sourceRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return candidate
            }
        }
        throw XCTSkip("Could not locate app source root from test path.")
    }

    private func writeSineWaveFixture(to url: URL) throws {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate / 4)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let channel = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let phase = (Double(frame) / sampleRate) * 440.0 * 2.0 * Double.pi
            channel[frame] = Float(sin(phase) * 0.8)
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}
